import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dictionary_providers.dart';
import 'learning_hub_language_provider.dart';
import 'scenario_providers.dart';
import 'sentence_progress_providers.dart';
import 'swipe_progress_providers.dart';

/// 학습 허브 언어 → 시나리오·기본문장·스와이프·사전 언어 동기화.
void selectLearningLanguage(WidgetRef ref, String language) {
  ref.read(learningHubLanguageProvider.notifier).set(language);
  ref.read(scenarioLanguageProvider.notifier).set(language);
  ref.read(basicSentenceLanguageProvider.notifier).set(language);
  ref.read(swipeLanguageProvider.notifier).set(language);
  ref.read(selectedLanguageProvider.notifier).set(language);
}
