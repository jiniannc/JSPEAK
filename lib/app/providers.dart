import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/config/audio_playback_url.dart';
import '../core/config/app_config.dart';
import '../core/logging/app_log.dart';
import '../core/utils/content_sync_status.dart';
import '../core/services/audio_player_service.dart';
import '../core/services/audio_prefetch.dart';
import '../core/network/apps_script_fetch.dart';
import '../data/datasources/local/audio_cache_datasource.dart';
import '../data/datasources/local/content_local_datasource.dart';
import '../data/datasources/remote/content_remote_datasource.dart';
import '../data/models/content_bundle.dart';
import '../data/models/sentence.dart';
import '../data/repositories/content_repository.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(
    remote: ContentRemoteDataSource(),
    local: ContentLocalDataSource(),
    audioCache: AudioCacheDataSource(),
    contentUrl: AppConfig.normalizedContentUrl,
  );
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});

/// 콘텐츠 상태: 로컬 데이터 + 동기화 진행 여부.
class ContentState {
  final ContentBundle bundle;
  final DateTime? lastSyncedAt;
  final bool syncing;
  final String? syncError;

  const ContentState({
    required this.bundle,
    this.lastSyncedAt,
    this.syncing = false,
    this.syncError,
  });

  ContentState copyWith({
    ContentBundle? bundle,
    DateTime? lastSyncedAt,
    bool? syncing,
    String? syncError,
    bool clearError = false,
  }) {
    return ContentState(
      bundle: bundle ?? this.bundle,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncing: syncing ?? this.syncing,
      syncError: clearError ? null : (syncError ?? this.syncError),
    );
  }
}

class ContentController extends AsyncNotifier<ContentState> {
  ContentRepository get _repo => ref.read(contentRepositoryProvider);

  @override
  Future<ContentState> build() async {
    // 1) 로컬 데이터를 먼저 올려 오프라인에서도 즉시 사용 가능하게 한다.
    final local = await _repo.loadLocal();
    final syncedAt = await _repo.lastSyncedAt();
    final initial = ContentState(
      bundle: local ?? ContentBundle.empty,
      lastSyncedAt: syncedAt,
    );

    // 2) 로컬이 비어 있으면(최초 실행) 동기화를 바로 시도한다.
    if (local == null) {
      try {
        final bundle = await _repo.sync();
        _warmAudioAfterLoad(bundle);
        _scheduleOfflineAudioPrefetch(bundle);
        return ContentState(bundle: bundle, lastSyncedAt: DateTime.now());
      } catch (e, st) {
        AppLog.warn('content_sync', '최초 동기화 실패', e, st);
        // 동기화 불가(URL 미설정·오프라인) 시 번들 샘플로 폴백해
        // 개발·데모 상태에서도 앱이 동작하게 한다.
        final sample = await _repo.loadBundledSample();
        return ContentState(
          bundle: sample,
          syncError: formatContentSyncError(e),
        );
      }
    }
    if (local.sentences.isNotEmpty) {
      _warmAudioAfterLoad(local);
      _scheduleOfflineAudioPrefetch(local);
    }
    Future.microtask(() => unawaited(sync()));
    return initial;
  }

  /// 모바일·네트워크 있을 때 문장 오디오 전체를 백그라운드 순차 다운로드.
  void _scheduleOfflineAudioPrefetch(ContentBundle bundle) {
    if (kIsWeb) return;
    Future.microtask(() {
      if (!ref.mounted) return;
      unawaited(
        ref.read(audioOfflinePrefetchProvider.notifier).scheduleForBundle(bundle),
      );
    });
  }

  /// 수동 동기화 (설정 화면 / 당겨서 새로고침).
  Future<void> sync() async {
    final current = state.value;
    if (current == null || current.syncing) return;
    state = AsyncData(current.copyWith(syncing: true, clearError: true));
    try {
      final bundle = await _repo.sync();
      _warmAudioAfterLoad(bundle);
      _scheduleOfflineAudioPrefetch(bundle);
      state = AsyncData(ContentState(
        bundle: bundle,
        lastSyncedAt: DateTime.now(),
      ));
    } catch (e, st) {
      AppLog.warn('content_sync', '동기화 실패', e, st);
      state = AsyncData(
        current.copyWith(
          syncing: false,
          syncError: formatContentSyncError(e),
        ),
      );
    }
  }
}

void _warmAudioAfterLoad(ContentBundle bundle) {
  if (bundle.sentences.isEmpty) return;
  AudioPrefetch.sentences(bundle.sentences, limit: 8);
  _warmAppsScriptProxy();
}

void _warmAppsScriptProxy() {
  final base = AppConfig.normalizedContentUrl;
  if (base.isEmpty) return;
  final uri = Uri.parse(base);
  final ping = uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'jspeak_ping': '1',
    },
  );
  AppsScriptFetch().getBytes(ping.toString()).then(
        (_) {},
        onError: (Object e, StackTrace st) {
          AppLog.debug('content_sync', 'Apps Script 워밍업 ping 실패', e, st);
        },
      );
}

final contentProvider =
    AsyncNotifierProvider<ContentController, ContentState>(
  ContentController.new,
);

/// 앱 실행·콘텐츠 동기화 후 오프라인용 오디오 전체 다운로드 (백그라운드).
/// 스플래시·메인 화면 전환을 막지 않으며, [Future]는 호출부에서 await 하지 않는다.
class AudioOfflinePrefetchState {
  final bool running;
  final int done;
  final int total;
  final DateTime? lastCompletedAt;

  /// 마지막 완료 시 실제 저장에 성공한 파일 수.
  final int lastSucceeded;

  const AudioOfflinePrefetchState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.lastCompletedAt,
    this.lastSucceeded = 0,
  });

  double get progress =>
      total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

  AudioOfflinePrefetchState copyWith({
    bool? running,
    int? done,
    int? total,
    DateTime? lastCompletedAt,
    int? lastSucceeded,
  }) {
    return AudioOfflinePrefetchState(
      running: running ?? this.running,
      done: done ?? this.done,
      total: total ?? this.total,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastSucceeded: lastSucceeded ?? this.lastSucceeded,
    );
  }
}

class AudioOfflinePrefetchController extends Notifier<AudioOfflinePrefetchState> {
  int _runGeneration = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// 실행 중에 새 번들이 오면(동기화·네트워크 복구) 끝난 뒤 한 번 더 돈다.
  ContentBundle? _pendingBundle;

  @override
  AudioOfflinePrefetchState build() {
    if (!kIsWeb) {
      _connectivitySub ??= Connectivity().onConnectivityChanged.listen(
        (results) => _onConnectivityChanged(results),
      );
      ref.onDispose(() {
        unawaited(_connectivitySub?.cancel());
        _connectivitySub = null;
      });
    }
    return const AudioOfflinePrefetchState();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!_hasUsableNetwork(results)) return;
    final bundle = ref.read(contentProvider).value?.bundle;
    if (bundle == null || bundle.isEmpty) return;
    unawaited(scheduleForBundle(bundle));
  }

  bool _hasUsableNetwork(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
  }

  Future<bool> _canDownloadNow() async {
    final results = await Connectivity().checkConnectivity();
    return _hasUsableNetwork(results);
  }

  Future<void> scheduleForBundle(ContentBundle bundle) async {
    if (kIsWeb) return;
    if (!AppConfig.isConfigured) return;
    if (bundle.isEmpty) return;
    if (state.running) {
      _pendingBundle = bundle;
      return;
    }
    if (!await _canDownloadNow()) return;
    if (state.running) {
      _pendingBundle = bundle;
      return;
    }

    final gen = ++_runGeneration;
    state = state.copyWith(running: true, done: 0, total: 0);

    try {
      final repo = ref.read(contentRepositoryProvider);
      final succeeded = await repo.prefetchAllAudio(
        bundle,
        onProgress: (done, total) {
          if (!ref.mounted || gen != _runGeneration) return;
          state = state.copyWith(done: done, total: total);
        },
      );
      if (!ref.mounted || gen != _runGeneration) return;
      state = state.copyWith(
        running: false,
        lastCompletedAt: DateTime.now(),
        lastSucceeded: succeeded,
      );
    } catch (e, st) {
      AppLog.debug('audio_offline', '전체 오디오 자동 다운로드 실패', e, st);
      if (ref.mounted && gen == _runGeneration) {
        state = state.copyWith(running: false);
      }
    }

    final next = _pendingBundle;
    _pendingBundle = null;
    if (next != null && ref.mounted) {
      unawaited(scheduleForBundle(next));
    }
  }
}

final audioOfflinePrefetchProvider =
    NotifierProvider<AudioOfflinePrefetchController, AudioOfflinePrefetchState>(
  AudioOfflinePrefetchController.new,
);

/// 현재 재생 중인 문장 상태.
class AudioState {
  final String? playingSentenceId;

  /// 현재 재생 중인 문장의 음성(여자/남자).
  final VoiceGender? playingVoice;
  final bool loading;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double playbackSpeed;

  const AudioState({
    this.playingSentenceId,
    this.playingVoice,
    this.loading = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackSpeed = 1.0,
  });

  bool get isActive => playingSentenceId != null;

  AudioState copyWith({
    String? playingSentenceId,
    bool? loading,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? playbackSpeed,
    bool clearPlaying = false,
  }) {
    return AudioState(
      playingSentenceId:
          clearPlaying ? null : (playingSentenceId ?? this.playingSentenceId),
      playingVoice: clearPlaying ? null : playingVoice,
      loading: loading ?? this.loading,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}

class AudioController extends Notifier<AudioState> {
  @override
  AudioState build() {
    final service = ref.watch(audioPlayerServiceProvider);

    final playerSub = service.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        // 재생 컨텍스트(문장 id·duration)는 유지 — 재재생 시 가라오케/플레이헤드가
        // duration=0으로 리셋되거나 isThisAudio가 false가 되는 것을 방지한다.
        if (!state.isActive || state.loading) return;
        state = state.copyWith(
          isPlaying: false,
          position: Duration.zero,
        );
        return;
      }
      if (state.isActive) {
        state = state.copyWith(isPlaying: playerState.playing);
      }
    });

    final positionSub = service.positionStream.listen((position) {
      // paused/completed 상태의 stale position 이벤트가 UI만 움직이는 것을 방지.
      if (state.isActive && (state.isPlaying || state.loading)) {
        state = state.copyWith(position: position);
      }
    });

    final durationSub = service.durationStream.listen((duration) {
      if (state.isActive && duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    ref.onDispose(() {
      playerSub.cancel();
      positionSub.cancel();
      durationSub.cancel();
    });

    return const AudioState();
  }

  /// 이 문장·음성이 현재 재생 컨텍스트인지.
  bool _isCurrent(Sentence sentence, VoiceGender? voice) =>
      state.playingSentenceId == sentence.id && state.playingVoice == voice;

  /// 리스트 모드 — 같은 문장이면 정지, 아니면 재생.
  Future<void> toggle(
    Sentence sentence, {
    VoiceGender voice = VoiceGender.female,
  }) async {
    if (state.playingSentenceId == sentence.id) {
      await stop();
      return;
    }
    AudioPrefetch.sentence(sentence, voice: voice);
    await play(sentence, voice: voice);
  }

  /// 문장 스피킹 카테고리(괄호 그룹) 전체 — 여·남 URL을 백그라운드로 받는다.
  void prefetchCategory(Iterable<Sentence> sentences) {
    for (final sentence in sentences) {
      if (!sentence.hasAnyAudio) continue;
      if (sentence.audioUrl.isNotEmpty) {
        prefetch(sentence, voice: VoiceGender.female);
      }
      if (sentence.audioUrlMale.isNotEmpty) {
        prefetch(sentence, voice: VoiceGender.male);
      }
    }
  }

  /// 화면 진입 시 미리 받기 — 메모리 캐시 + (모바일) 디스크 캐시.
  void prefetch(
    Sentence sentence, {
    VoiceGender voice = VoiceGender.female,
  }) {
    final rawUrl = sentence.audioUrlFor(voice);
    if (rawUrl.isEmpty) return;
    AudioPrefetch.sentence(sentence, voice: voice);
    if (kIsWeb) return;
    final playbackUrl = AudioPlaybackUrl.resolve(rawUrl);
    if (playbackUrl.isEmpty) return;
    unawaited(
      ref.read(contentRepositoryProvider).cacheAudioInBackground(playbackUrl),
    );
  }

  /// 학습 모드 — 재생 시작. [voice] 음성이 없으면 다른 음성으로 재생한다.
  Future<void> play(
    Sentence sentence, {
    VoiceGender voice = VoiceGender.female,
  }) async {
    final service = ref.read(audioPlayerServiceProvider);
    final repo = ref.read(contentRepositoryProvider);
    final resolvedVoice = sentence.resolveVoice(voice);
    if (resolvedVoice == null) return;

    final playbackUrl =
        AudioPlaybackUrl.resolve(sentence.rawAudioUrlFor(resolvedVoice));
    if (playbackUrl.isEmpty) return;

    final sameAudio = _isCurrent(sentence, resolvedVoice);
    final preservedDuration = sameAudio && state.duration.inMilliseconds > 0
        ? state.duration
        : Duration.zero;

    state = AudioState(
      playingSentenceId: sentence.id,
      playingVoice: resolvedVoice,
      loading: true,
      playbackSpeed: state.playbackSpeed,
      duration: preservedDuration,
    );

    try {
      await service.setSpeed(state.playbackSpeed);

      // 웹: 디스크 캐시 없음 → 메모리 캐시 + 스트리밍.
      // 모바일: 로컬 파일 재생이 가장 안정적. 없으면 받을 때까지 기다렸다 재생.
      String? localPath;
      if (!kIsWeb) {
        localPath = await repo.cachedAudioPath(playbackUrl);
        localPath ??= await repo.localAudioPath(playbackUrl);
      }
      if (!_isCurrent(sentence, resolvedVoice)) return;

      var playedFromFile = false;
      if (localPath != null) {
        try {
          await service.playFile(localPath);
          playedFromFile = true;
        } catch (e, st) {
          // 손상된 캐시 파일 — 지우고 온라인으로 한 번 더 시도한다.
          AppLog.warn('audio', '캐시 파일 재생 실패, 온라인 재시도: $playbackUrl', e, st);
          await repo.evictCachedAudio(playbackUrl);
          if (!_isCurrent(sentence, resolvedVoice)) return;
        }
      }
      if (!playedFromFile) {
        // 디스크에 없거나 받기 실패 — 온라인 재생 (오프라인 다운로드 완료 전에도 동작).
        await service.playUrl(playbackUrl);
        if (!kIsWeb) {
          unawaited(repo.cacheAudioInBackground(playbackUrl));
        }
      }
      if (!_isCurrent(sentence, resolvedVoice)) return;

      final resolved = await service.resolveDuration();
      final duration = resolved.inMilliseconds > 0
          ? resolved
          : preservedDuration;
      state = state.copyWith(
        loading: false,
        isPlaying: service.isPlaying,
        duration: duration,
        position: Duration.zero,
      );
    } catch (e, st) {
      AppLog.warn('audio', '오디오 재생 실패: $playbackUrl', e, st);
      if (!_isCurrent(sentence, resolvedVoice)) return;
      final speed = state.playbackSpeed;
      state = AudioState(playbackSpeed: speed);
    }
  }

  Future<void> togglePlayPause(
    Sentence sentence, {
    VoiceGender voice = VoiceGender.female,
  }) async {
    final service = ref.read(audioPlayerServiceProvider);
    if (!_isCurrent(sentence, sentence.resolveVoice(voice))) {
      await play(sentence, voice: voice);
      return;
    }
    // 받는 중 재탭 — resume()하면 이전 문장 소스가 재생될 수 있어 무시한다.
    if (state.loading) return;
    if (state.isPlaying) {
      await service.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      if (service.processingState == ProcessingState.completed) {
        // completed 상태에서 seek+resume만 하면 Web 등에서 무음·유령 position
        // 업데이트가 발생할 수 있어 소스를 다시 올린다.
        await play(sentence, voice: voice);
        return;
      }
      await service.resume();
      final duration = state.duration.inMilliseconds > 0
          ? state.duration
          : await service.resolveDuration();
      state = state.copyWith(
        isPlaying: true,
        duration: duration,
      );
    }
  }

  Future<void> seekToProgress(double value) async {
    if (!state.isActive || state.duration == Duration.zero) return;
    final service = ref.read(audioPlayerServiceProvider);
    final target = Duration(
      milliseconds: (state.duration.inMilliseconds * value.clamp(0.0, 1.0))
          .round(),
    );
    await service.seek(target);
    state = state.copyWith(position: target);
  }

  Future<void> restart(
    Sentence sentence, {
    VoiceGender voice = VoiceGender.female,
  }) async {
    final service = ref.read(audioPlayerServiceProvider);
    if (_isCurrent(sentence, sentence.resolveVoice(voice)) && state.loading) {
      return;
    }
    if (!_isCurrent(sentence, sentence.resolveVoice(voice)) ||
        !state.isActive ||
        service.processingState == ProcessingState.completed) {
      await play(sentence, voice: voice);
      return;
    }
    await service.seek(Duration.zero);
    if (!service.isPlaying) {
      await service.resume();
    }
    state = state.copyWith(
      isPlaying: service.isPlaying,
      position: Duration.zero,
    );
  }

  Future<void> setSpeed(double speed) async {
    final service = ref.read(audioPlayerServiceProvider);
    await service.setSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  Future<void> stop() async {
    final service = ref.read(audioPlayerServiceProvider);
    await service.stop();
    if (!ref.mounted) return;
    state = AudioState(playbackSpeed: state.playbackSpeed);
  }
}

final audioProvider = NotifierProvider<AudioController, AudioState>(
  AudioController.new,
);
