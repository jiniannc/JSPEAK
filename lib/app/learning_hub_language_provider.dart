import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 학습 허브에서 선택한 언어 — 각 모드 진입 시 동일 언어로 시작.
class LearningHubLanguageController extends Notifier<String> {
  @override
  String build() => 'English';

  void set(String language) => state = language;
}

final learningHubLanguageProvider =
    NotifierProvider<LearningHubLanguageController, String>(
  LearningHubLanguageController.new,
);
