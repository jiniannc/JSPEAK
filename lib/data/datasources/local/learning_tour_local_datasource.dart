import 'package:hive_flutter/hive_flutter.dart';

/// 학습 모드별 코치마크 투어 완료 여부.
class LearningTourLocalDataSource {
  static const _boxName = 'jspeak_learning_tour';
  static const _keyHasCompletedLearningTour = 'hasCompletedLearningTour';
  static const _keyHasCompletedWordSwipeTour = 'hasCompletedWordSwipeTour';
  static const _keyHasCompletedScenarioTour = 'hasCompletedScenarioTour';

  Box<bool>? _box;

  Future<Box<bool>> _openBox() async {
    return _box ??= await Hive.openBox<bool>(_boxName);
  }

  Future<bool> hasCompletedLearningTour() async {
    final box = await _openBox();
    return box.get(_keyHasCompletedLearningTour) ?? false;
  }

  Future<void> setCompletedLearningTour(bool value) async {
    final box = await _openBox();
    await box.put(_keyHasCompletedLearningTour, value);
  }

  Future<bool> hasCompletedWordSwipeTour() async {
    final box = await _openBox();
    return box.get(_keyHasCompletedWordSwipeTour) ?? false;
  }

  Future<void> setCompletedWordSwipeTour(bool value) async {
    final box = await _openBox();
    await box.put(_keyHasCompletedWordSwipeTour, value);
  }

  Future<bool> hasCompletedScenarioTour() async {
    final box = await _openBox();
    return box.get(_keyHasCompletedScenarioTour) ?? false;
  }

  Future<void> setCompletedScenarioTour(bool value) async {
    final box = await _openBox();
    await box.put(_keyHasCompletedScenarioTour, value);
  }
}
