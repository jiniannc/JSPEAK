import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// flutter_tts 래퍼.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  int _speakGen = 0;
  Completer<void>? _activeSpeak;

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

  void _finishActiveSpeak() {
    final completer = _activeSpeak;
    _activeSpeak = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _beginSpeak(
    String text, {
    required String language,
    void Function(int start, int end, String word)? onProgress,
  }) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();

    final gen = ++_speakGen;
    _finishActiveSpeak();
    await _tts.stop();
    await _tts.setLanguage(localeFor(language));

    final completer = Completer<void>();
    _activeSpeak = completer;

    void finishIfCurrent() {
      if (gen != _speakGen) return;
      _finishActiveSpeak();
    }

    _tts.setProgressHandler((spoken, start, end, word) {
      if (gen != _speakGen) return;
      onProgress?.call(start, end, word);
    });
    _tts.setCompletionHandler(finishIfCurrent);
    _tts.setCancelHandler(finishIfCurrent);
    _tts.setErrorHandler((_) => finishIfCurrent());

    await _tts.speak(text);
  }

  Future<void> speak(String text, {required String language}) async {
    await _beginSpeak(text, language: language);
  }

  /// TTS 재생이 끝날 때까지 대기한다.
  Future<void> speakAndWait(String text, {required String language}) async {
    await _beginSpeak(text, language: language);
    await _activeSpeak?.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  /// 단어 단위 진행 콜백과 함께 읽고, 재생이 끝날 때까지 대기한다.
  Future<void> speakWithProgress(
    String text, {
    required String language,
    void Function(int start, int end, String word)? onProgress,
  }) async {
    await _beginSpeak(
      text,
      language: language,
      onProgress: onProgress,
    );
    await _activeSpeak?.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  Future<void> stop() async {
    _speakGen++;
    _finishActiveSpeak();
    await _tts.stop();
  }
}
