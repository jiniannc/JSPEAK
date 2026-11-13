import 'package:hive_flutter/hive_flutter.dart';

import '../../models/sentence.dart';

/// 문장 스피킹 모드에서 고른 원어민 음성(여자/남자).
class VoicePreferenceLocalDataSource {
  static const _boxName = 'jspeak_voice_preference';
  static const _keySentenceVoice = 'sentenceVoice';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<VoiceGender> loadSentenceVoice() async {
    final box = await _openBox();
    final raw = box.get(_keySentenceVoice);
    return VoiceGender.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => VoiceGender.female,
    );
  }

  Future<void> saveSentenceVoice(VoiceGender voice) async {
    final box = await _openBox();
    await box.put(_keySentenceVoice, voice.name);
  }
}
