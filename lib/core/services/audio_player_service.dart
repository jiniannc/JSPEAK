import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

import '../network/apps_script_fetch.dart';
import 'dio_stream_audio_source.dart';

/// 앱 전체에서 오디오 플레이어를 하나만 사용한다.
/// 새 문장을 재생하면 기존 재생은 자동으로 중단된다 (기존 웹의 동시재생 방지와 동일).
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _player.playing;

  ProcessingState get processingState => _player.processingState;

  Future<void> playFile(String path) async {
    await loadFile(path);
    unawaited(_player.play());
  }

  Future<void> playUrl(String url) async {
    await loadUrl(url);
    unawaited(_player.play());
  }

  Future<void> loadFile(String path) async {
    await _player.stop();
    await _player.setFilePath(path);
  }

  Future<void> loadUrl(String url) async {
    await _player.stop();
    if (kIsWeb || AppsScriptFetch.isWebAppUrl(url)) {
      await _player.setAudioSource(DioStreamAudioSource(url));
    } else {
      await _player.setUrl(url);
    }
  }

  Future<void> startPlayback() async {
    unawaited(_player.play());
  }

  Future<void> loadConcatenating(List<AudioSource> sources) async {
    await _player.stop();
    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
    );
  }

  Stream<SequenceState> get sequenceStateStream => _player.sequenceStateStream;

  List<IndexedAudioSource> get sequence => _player.sequence;

  int? get currentIndex => _player.currentIndex;

  Future<void> pause() => _player.pause();

  Future<void> resume() async {
    unawaited(_player.play());
  }

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() => _player.stop();

  /// [setFilePath]/[setUrl] 직후에는 durationStream이 재방출되지 않을 수 있어
  /// 플레이어에 이미 올라온 길이를 우선 읽고, 없으면 스트림 1회를 기다린다.
  Future<Duration> resolveDuration({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final immediate = _player.duration;
    if (immediate != null && immediate.inMilliseconds > 0) {
      return immediate;
    }

    try {
      return await _player.durationStream
          .map((d) => d ?? Duration.zero)
          .firstWhere((d) => d.inMilliseconds > 0)
          .timeout(timeout);
    } catch (_) {
      return immediate ?? Duration.zero;
    }
  }

  Future<void> dispose() => _player.dispose();
}
