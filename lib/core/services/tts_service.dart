import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// flutter_tts 래퍼.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  static String localeFor(String language) {
    return switch (language) {
      'English' => 'en-US',
      'Japanese' => 'ja-JP',
      'Chinese' => 'zh-CN',
      _ => 'en-US',
    };
  }

  Future<void> speak(String text, {required String language}) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await _tts.stop();
    await _tts.setLanguage(localeFor(language));
    await _tts.speak(text);
  }

  /// TTS 재생이 끝날 때까지 대기한다.
  Future<void> speakAndWait(String text, {required String language}) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await _tts.stop();
    await _tts.setLanguage(localeFor(language));

    final completer = Completer<void>();
    void handler() {
      if (!completer.isCompleted) completer.complete();
    }

    _tts.setCompletionHandler(handler);
    await _tts.speak(text);
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  Future<void> stop() => _tts.stop();
}
