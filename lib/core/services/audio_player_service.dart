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

  Future<void> playFile(String path) async {
    await _player.stop();
    await _player.setFilePath(path);
    await _player.play();
  }

  Future<void> playUrl(String url) async {
    await _player.stop();
    if (kIsWeb || AppsScriptFetch.isWebAppUrl(url)) {
      await _player.setAudioSource(DioStreamAudioSource(url));
    } else {
      await _player.setUrl(url);
    }
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
