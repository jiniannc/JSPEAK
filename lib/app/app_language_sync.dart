import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dictionary_providers.dart';

/// 앱 전역 언어 변경 — [appLanguageProvider] 단일 소스.
void syncAppLanguage(
  WidgetRef ref,
  String language, {
  bool resetDictionaryCategory = false,
}) {
  ref.read(appLanguageProvider.notifier).set(language);
  if (resetDictionaryCategory) {
    ref.read(selectedCategoryProvider.notifier).set(null);
  }
}
