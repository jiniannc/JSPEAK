import 'package:hive_flutter/hive_flutter.dart';

/// 모드별 안내 카드 닫힘 여부 저장.
class GuideDismissLocalDataSource {
  static const _boxName = 'jspeak_guide_dismiss';
  static const keyScenario = 'scenario';
  static const keyWordSwipe = 'word_swipe';
  static const keyBasicSentence = 'basic_sentence';

  Box<bool>? _box;

  Future<Box<bool>> _openBox() async {
    return _box ??= await Hive.openBox<bool>(_boxName);
  }

  Future<bool> isDismissed(String key) async {
    final box = await _openBox();
    return box.get(key) == true;
  }

  Future<void> dismiss(String key) async {
    final box = await _openBox();
    await box.put(key, true);
  }

  Future<void> restore(String key) async {
    final box = await _openBox();
    await box.put(key, false);
  }

  Future<Map<String, bool>> loadAll() async {
    final box = await _openBox();
    return {
      keyScenario: box.get(keyScenario) == true,
      keyWordSwipe: box.get(keyWordSwipe) == true,
      keyBasicSentence: box.get(keyBasicSentence) == true,
    };
  }
}
