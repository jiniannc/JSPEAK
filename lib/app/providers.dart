import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/config/audio_playback_url.dart';
import '../core/config/app_config.dart';
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
    contentUrl: AppConfig.contentUrl,
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
        return ContentState(bundle: bundle, lastSyncedAt: DateTime.now());
      } catch (e) {
        // 동기화 불가(URL 미설정·오프라인) 시 번들 샘플로 폴백해
        // 개발·데모 상태에서도 앱이 동작하게 한다.
        final sample = await _repo.loadBundledSample();
        return ContentState(bundle: sample, syncError: e.toString());
      }
    }
    if (local.sentences.isNotEmpty) {
      _warmAudioAfterLoad(local);
    }
    return initial;
  }

  /// 수동 동기화 (설정 화면 / 당겨서 새로고침).
  Future<void> sync() async {
    final current = state.value;
    if (current == null || current.syncing) return;
    state = AsyncData(current.copyWith(syncing: true, clearError: true));
    try {
      final bundle = await _repo.sync();
      _warmAudioAfterLoad(bundle);
      state = AsyncData(ContentState(
        bundle: bundle,
        lastSyncedAt: DateTime.now(),
      ));
    } catch (e) {
      state = AsyncData(
        current.copyWith(syncing: false, syncError: e.toString()),
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
  final base = AppConfig.contentUrl;
  if (base.isEmpty) return;
  final uri = Uri.parse(base);
  final ping = uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'jspeak_ping': '1',
    },
  );
  AppsScriptFetch().getBytes(ping.toString()).then((_) {}, onError: (Object _, StackTrace __) {});
}

final contentProvider =
    AsyncNotifierProvider<ContentController, ContentState>(
  ContentController.new,
);

/// 현재 재생 중인 문장 상태.
class AudioState {
  final String? playingSentenceId;
  final bool loading;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double playbackSpeed;

  const AudioState({
    this.playingSentenceId,
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
        state = state.copyWith(
          clearPlaying: true,
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
      if (state.isActive) {
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

  /// 리스트 모드 — 같은 문장이면 정지, 아니면 재생.
  Future<void> toggle(Sentence sentence) async {
    if (state.playingSentenceId == sentence.id) {
      await stop();
      return;
    }
    AudioPrefetch.sentence(sentence);
    await play(sentence);
  }

  /// 화면 진입 시 미리 받기.
  void prefetch(Sentence sentence) => AudioPrefetch.sentence(sentence);

  /// 학습 모드 — 재생 시작.
  Future<void> play(Sentence sentence) async {
    final service = ref.read(audioPlayerServiceProvider);
    final repo = ref.read(contentRepositoryProvider);
    if (sentence.audioUrl.isEmpty) return;

    final playbackUrl = AudioPlaybackUrl.resolve(sentence.audioUrl);
    if (playbackUrl.isEmpty) return;

    state = AudioState(
      playingSentenceId: sentence.id,
      loading: true,
      playbackSpeed: state.playbackSpeed,
    );

    try {
      await service.setSpeed(state.playbackSpeed);

      // 웹: 디스크 캐시 없음 → 메모리 캐시 + 스트리밍.
      // 모바일: 디스크에 있으면 즉시, 없으면 네트워크 재생 후 백그라운드 저장.
      String? localPath;
      if (!kIsWeb) {
        localPath = await repo.cachedAudioPath(playbackUrl);
      }
      if (state.playingSentenceId != sentence.id) return;

      if (localPath != null) {
        await service.playFile(localPath);
      } else {
        await service.playUrl(playbackUrl);
        if (!kIsWeb) {
          unawaited(repo.cacheAudioInBackground(playbackUrl));
        }
      }
      state = state.copyWith(loading: false, isPlaying: true);
    } catch (e, st) {
      debugPrint('오디오 재생 실패: $playbackUrl');
      debugPrint('$e\n$st');
      final speed = state.playbackSpeed;
      state = AudioState(playbackSpeed: speed);
    }
  }

  Future<void> togglePlayPause(Sentence sentence) async {
    final service = ref.read(audioPlayerServiceProvider);
    if (state.playingSentenceId != sentence.id) {
      await play(sentence);
      return;
    }
    if (state.isPlaying) {
      await service.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await service.resume();
      state = state.copyWith(isPlaying: true);
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

  Future<void> restart() async {
    if (!state.isActive) return;
    final service = ref.read(audioPlayerServiceProvider);
    await service.seek(Duration.zero);
    if (!state.isPlaying) {
      await service.resume();
      state = state.copyWith(position: Duration.zero, isPlaying: true);
    } else {
      state = state.copyWith(position: Duration.zero);
    }
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
