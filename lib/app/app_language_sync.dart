import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dictionary_providers.dart';
import 'learning_hub_language_provider.dart';
import 'scenario_providers.dart';
import 'sentence_progress_providers.dart';
import 'swipe_progress_providers.dart';

/// 앱 전역 언어 선택 — 홈·학습·기내사전·각 학습 모드가 동일 언어를 유지한다.
void syncAppLanguage(
  WidgetRef ref,
  String language, {
  bool resetDictionaryCategory = false,
}) {
  ref.read(learningHubLanguageProvider.notifier).set(language);
  ref.read(scenarioLanguageProvider.notifier).set(language);
  ref.read(basicSentenceLanguageProvider.notifier).set(language);
  ref.read(swipeLanguageProvider.notifier).set(language);
  ref.read(selectedLanguageProvider.notifier).set(language);
  if (resetDictionaryCategory) {
    ref.read(selectedCategoryProvider.notifier).set(null);
  }
}
