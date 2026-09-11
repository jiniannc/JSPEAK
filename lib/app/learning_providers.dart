import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_language_sync.dart';

export 'app_language_sync.dart' show syncAppLanguage;

/// 홈·학습 헤더 언어 선택.
void selectLearningLanguage(WidgetRef ref, String language) {
  syncAppLanguage(ref, language);
}

/// 기내사전 헤더 언어 선택 — 홈·학습과 동기화, 카테고리는 리셋.
void selectDictionaryLanguage(WidgetRef ref, String language) {
  syncAppLanguage(ref, language, resetDictionaryCategory: true);
}
