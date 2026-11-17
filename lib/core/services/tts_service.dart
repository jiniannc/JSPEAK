import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/sentence.dart';

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
    VoiceGender? voice,
    void Function(int start, int end, String word)? onProgress,
  }) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();

    final gen = ++_speakGen;
    _finishActiveSpeak();
    await _tts.stop();
    await _applyLanguageAndVoice(language, voice);

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

  Future<void> speak(
    String text, {
    required String language,
    VoiceGender? voice,
  }) async {
    await _beginSpeak(text, language: language, voice: voice);
  }

  /// TTS 재생이 끝날 때까지 대기한다.
  Future<void> speakAndWait(
    String text, {
    required String language,
    VoiceGender? voice,
  }) async {
    await _beginSpeak(text, language: language, voice: voice);
    await _activeSpeak?.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  /// 단어 단위 진행 콜백과 함께 읽고, 재생이 끝날 때까지 대기한다.
  Future<void> speakWithProgress(
    String text, {
    required String language,
    VoiceGender? voice,
    void Function(int start, int end, String word)? onProgress,
  }) async {
    await _beginSpeak(
      text,
      language: language,
      voice: voice,
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

  Future<void> _applyLanguageAndVoice(
    String language,
    VoiceGender? voice,
  ) async {
    final locale = localeFor(language);
    await _tts.setLanguage(locale);
    if (voice == null) {
      await _tts.setPitch(1.0);
      return;
    }

    final pitch = voice == VoiceGender.male ? 0.88 : 1.05;
    await _tts.setPitch(pitch);

    final picked = await _pickSystemVoice(locale, voice);
    if (picked != null) {
      try {
        await _tts.setVoice(picked);
      } catch (_) {
        // 플랫폼별 setVoice 실패 시 언어·피치만 적용.
      }
    }
  }

  Future<Map<String, String>?> _pickSystemVoice(
    String locale,
    VoiceGender gender,
  ) async {
    dynamic raw;
    try {
      raw = await _tts.getVoices;
    } catch (_) {
      return null;
    }
    if (raw is! List || raw.isEmpty) return null;

    final localeLower = locale.toLowerCase();
    final langPrefix = localeLower.split('-').first;
    final candidates = <Map<String, String>>[];

    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString() ?? '';
      final loc = entry['locale']?.toString() ?? '';
      if (name.isEmpty || loc.isEmpty) continue;
      final locLower = loc.toLowerCase();
      if (!locLower.startsWith(langPrefix)) continue;
      candidates.add({'name': name, 'locale': loc});
    }
    if (candidates.isEmpty) return null;

    bool matchesGender(String name, VoiceGender g) {
      final n = name.toLowerCase();
      const femaleHints = [
        'female',
        'woman',
        'girl',
        'samantha',
        'victoria',
        'karen',
        'zira',
        'susan',
        'kyoko',
        'yuna',
        'xiaoxiao',
        'tingting',
      ];
      const maleHints = [
        'male',
        'man',
        'boy',
        'daniel',
        'david',
        'james',
        'richard',
        'otoya',
        'yunxi',
        'kangkang',
      ];
      final female = femaleHints.any(n.contains);
      final male = maleHints.any(n.contains);
      if (g == VoiceGender.female) {
        return female && !male;
      }
      return male && !female;
    }

    for (final c in candidates) {
      if (matchesGender(c['name']!, gender)) return c;
    }

    // 힌트가 없으면 목록 순서로 대략 구분 (앞쪽 여성, 뒤쪽 남성에 가깝게).
    if (gender == VoiceGender.male && candidates.length > 1) {
      return candidates[candidates.length - 1];
    }
    return candidates.first;
  }
}
