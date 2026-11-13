import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 전역 학습·사전 언어 (단일 소스).
///
/// 허브·시나리오·기본문장·스와이프·사전은 [appLanguageProvider]를
/// watch/read 하며, 변경은 [syncAppLanguage] 또는 [AppLanguageController.set]만 사용.
class AppLanguageController extends Notifier<String> {
  @override
  String build() => 'English';

  void set(String language) => state = language;
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, String>(
  AppLanguageController.new,
);

/// 학습 허브 — [appLanguageProvider]와 동일.
final learningHubLanguageProvider = appLanguageProvider;

/// 기내 사전 — [appLanguageProvider]와 동일.
final selectedLanguageProvider = appLanguageProvider;

/// 시나리오 모드 — [appLanguageProvider]와 동일.
final scenarioLanguageProvider = appLanguageProvider;

/// 기본 문장 모드 — [appLanguageProvider]와 동일.
final basicSentenceLanguageProvider = appLanguageProvider;

/// 단어 스와이프 — [appLanguageProvider]와 동일.
final swipeLanguageProvider = appLanguageProvider;
