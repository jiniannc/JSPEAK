import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/content_bundle.dart';
import '../data/repositories/scenario_progress_repository.dart';
import '../data/repositories/sentence_progress_repository.dart';
import '../data/repositories/swipe_progress_repository.dart';
import '../data/datasources/local/scenario_progress_local_datasource.dart';
import '../data/datasources/local/sentence_progress_local_datasource.dart';
import '../data/datasources/local/swipe_progress_local_datasource.dart';
import 'dictionary_providers.dart';
import 'learning_hub_language_provider.dart';
import 'providers.dart';
import 'scenario_providers.dart';
import 'sentence_progress_providers.dart';
import 'swipe_progress_providers.dart';

/// 비행 여권 칭호 뱃지 정의.
class PassportTitleBadge {
  final String id;
  final String emoji;
  final String title;
  final bool unlocked;
  final String lockHint;

  const PassportTitleBadge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.unlocked,
    required this.lockHint,
  });
}

/// 선택 언어 기준 3대 모드 미션 진행.
class MyPageLanguageMissionProgress {
  final String language;
  final SentenceCategorySummary stampSummary;
  final int stampTotalEarned;
  final int stampTotalPossible;
  final double sentencePercent;
  final int scenarioCompleted;
  final int scenarioTotal;
  final double scenarioPercent;
  final int swipeKnown;
  final int swipeTotal;
  final double swipePercent;
  final double overallPercent;

  const MyPageLanguageMissionProgress({
    required this.language,
    required this.stampSummary,
    required this.stampTotalEarned,
    required this.stampTotalPossible,
    required this.sentencePercent,
    required this.scenarioCompleted,
    required this.scenarioTotal,
    required this.scenarioPercent,
    required this.swipeKnown,
    required this.swipeTotal,
    required this.swipePercent,
    required this.overallPercent,
  });
}

class MyPagePassportReport {
  final String selectedLanguage;
  final double overallFlightProgress;
  final MyPageLanguageMissionProgress languageMission;
  final List<PassportTitleBadge> titleBadges;

  const MyPagePassportReport({
    required this.selectedLanguage,
    required this.overallFlightProgress,
    required this.languageMission,
    required this.titleBadges,
  });
}

bool _isBasicSentenceComplete(
  String language,
  SentenceCategorySummary summary,
) {
  return summary.total > 0 && summary.masteredCount >= summary.total;
}

bool _isScenarioComplete(double percent, int total) {
  return total > 0 && percent >= 99.9;
}

bool _isGlobalSwipeComplete({
  required int known,
  required int total,
}) {
  return total > 0 && known >= total;
}

MyPageLanguageMissionProgress _buildLanguageMission({
  required String language,
  required ContentBundle bundle,
  required SentenceProgressStats sentenceStats,
  required ScenarioProgressStats scenarioStats,
  required SwipeProgressStats swipeStats,
  required SentenceProgressRepository sentenceRepo,
  required ScenarioProgressRepository scenarioRepo,
  required SwipeProgressRepository swipeRepo,
}) {
  final stampSummary = sentenceRepo.languageStampSummary(
    language: language,
    bundle: bundle,
    stats: sentenceStats,
  );
  final stampEarned = stampSummary.readCount +
      stampSummary.attemptedCount +
      stampSummary.masteredCount;
  final stampPossible = stampSummary.total * 3;

  final sentencePercent = sentenceRepo.languageProgressPercent(
    language: language,
    bundle: bundle,
    stats: sentenceStats,
  );

  final scenarios = bundle.scenarios;
  final scenarioCompleted = scenarioRepo.completedCount(
    language: language,
    scenarios: scenarios,
    stats: scenarioStats,
  );
  final scenarioTotal = scenarioRepo.totalCount(
    language: language,
    scenarios: scenarios,
  );
  final scenarioPercent = scenarioRepo.progressPercent(
    language: language,
    scenarios: scenarios,
    stats: scenarioStats,
  );

  final swipeKnown = swipeRepo.languageKnownCount(
    language: language,
    bundle: bundle,
    stats: swipeStats,
  );
  final swipeTotal = swipeRepo.languageTotalCount(
    language: language,
    bundle: bundle,
  );
  final swipePercent = swipeRepo.languageProgressPercent(
    language: language,
    bundle: bundle,
    stats: swipeStats,
  );

  final overallPercent = (sentencePercent + scenarioPercent + swipePercent) / 3;

  return MyPageLanguageMissionProgress(
    language: language,
    stampSummary: stampSummary,
    stampTotalEarned: stampEarned,
    stampTotalPossible: stampPossible,
    sentencePercent: sentencePercent,
    scenarioCompleted: scenarioCompleted,
    scenarioTotal: scenarioTotal,
    scenarioPercent: scenarioPercent,
    swipeKnown: swipeKnown,
    swipeTotal: swipeTotal,
    swipePercent: swipePercent,
    overallPercent: overallPercent,
  );
}

bool _hasAnyChapterCleared({
  required ContentBundle bundle,
  required SentenceProgressStats sentenceStats,
  required ScenarioProgressStats scenarioStats,
  required SwipeProgressStats swipeStats,
  required SentenceProgressRepository sentenceRepo,
  required ScenarioProgressRepository scenarioRepo,
}) {
  const languages = ['English', 'Japanese', 'Chinese'];

  for (final language in languages) {
    final stampSummary = sentenceRepo.languageStampSummary(
      language: language,
      bundle: bundle,
      stats: sentenceStats,
    );
    if (stampSummary.readCount > 0 ||
        stampSummary.attemptedCount > 0 ||
        stampSummary.masteredCount > 0) {
      return true;
    }

    if (scenarioRepo.completedCount(
          language: language,
          scenarios: bundle.scenarios,
          stats: scenarioStats,
        ) >
        0) {
      return true;
    }

    for (final category in bundle.categoriesForWords(language)) {
      final progress = swipeStats.forCategory(language, category);
      if (progress.played) return true;
    }
  }

  return false;
}

List<PassportTitleBadge> _buildTitleBadges({
  required MyPageLanguageMissionProgress english,
  required MyPageLanguageMissionProgress japanese,
  required MyPageLanguageMissionProgress chinese,
  required bool globalSwipeComplete,
  required bool anyChapterCleared,
}) {
  final englishBasic = _isBasicSentenceComplete(
    'English',
    english.stampSummary,
  );
  final japaneseBasic = _isBasicSentenceComplete(
    'Japanese',
    japanese.stampSummary,
  );
  final chineseBasic = _isBasicSentenceComplete(
    'Chinese',
    chinese.stampSummary,
  );
  final englishScenario = _isScenarioComplete(
    english.scenarioPercent,
    english.scenarioTotal,
  );
  final japaneseScenario = _isScenarioComplete(
    japanese.scenarioPercent,
    japanese.scenarioTotal,
  );
  final chineseScenario = _isScenarioComplete(
    chinese.scenarioPercent,
    chinese.scenarioTotal,
  );

  final core = [
    PassportTitleBadge(
      id: 'first_step',
      emoji: '🛫',
      title: '시작이 반이다',
      unlocked: anyChapterCleared,
      lockHint: '기본문장·시나리오·단어 중 1개 챕터만 클리어해도 획득됩니다',
    ),
    PassportTitleBadge(
      id: 'perfect_voice',
      emoji: '✈️',
      title: '퍼펙트 보이스',
      unlocked: englishBasic,
      lockHint: '영어 기본 문장 모드를 완료하면 해제됩니다',
    ),
    PassportTitleBadge(
      id: 'polite_master',
      emoji: '🌸',
      title: '정중 응대 마스터',
      unlocked: japaneseBasic,
      lockHint: '일본어 기본 문장 모드를 완료하면 해제됩니다',
    ),
    PassportTitleBadge(
      id: 'tone_breaker',
      emoji: '🇨🇳',
      title: '성조 파괴자',
      unlocked: chineseBasic,
      lockHint: '중국어 기본 문장 모드를 완료하면 해제됩니다',
    ),
    PassportTitleBadge(
      id: 'situation_guardian',
      emoji: '🛡️',
      title: '돌발 상황 가디언',
      unlocked: englishScenario,
      lockHint: '영어 시나리오 모드를 완료하면 해제됩니다',
    ),
    PassportTitleBadge(
      id: 'all_weather_japanese',
      emoji: '🎌',
      title: '전천후 일어 해결사',
      unlocked: japaneseScenario,
      lockHint: '일본어 시나리오 모드를 완료하면 해제됩니다',
    ),
    PassportTitleBadge(
      id: 'inflight_talk_king',
      emoji: '💬',
      title: '실전 기내 대화왕',
      unlocked: chineseScenario,
      lockHint: '중국어 시나리오 모드를 완료하면 해제됩니다',
    ),
    PassportTitleBadge(
      id: 'walking_dictionary',
      emoji: '🔤',
      title: '기내 걸어다니는 사전',
      unlocked: globalSwipeComplete,
      lockHint: '기내 단어 스와이프 모드를 완료하면 해제됩니다',
    ),
  ];

  final allUnlocked = core.every((b) => b.unlocked);
  return [
    ...core,
    PassportTitleBadge(
      id: 'first_class_multi_crew',
      emoji: '👑',
      title: '퍼스트클래스 멀티 크루',
      unlocked: allUnlocked,
      lockHint: '모든 비행 칭호를 획득하면 해제됩니다',
    ),
  ];
}

final myPagePassportReportProvider = Provider<MyPagePassportReport?>((ref) {
  final content = ref.watch(contentProvider).value;
  if (content == null) return null;

  final selectedLanguage = ref.watch(learningHubLanguageProvider);
  final bundle = content.bundle;
  final sentenceStats = ref.watch(sentenceProgressProvider).stats;
  final scenarioStats = ref.watch(scenarioProgressProvider).stats;
  final swipeStats = ref.watch(swipeProgressProvider).stats;

  final sentenceRepo = ref.watch(sentenceProgressRepositoryProvider);
  final scenarioRepo = ref.watch(scenarioProgressRepositoryProvider);
  final swipeRepo = ref.watch(swipeProgressRepositoryProvider);

  final english = _buildLanguageMission(
    language: 'English',
    bundle: bundle,
    sentenceStats: sentenceStats,
    scenarioStats: scenarioStats,
    swipeStats: swipeStats,
    sentenceRepo: sentenceRepo,
    scenarioRepo: scenarioRepo,
    swipeRepo: swipeRepo,
  );
  final japanese = _buildLanguageMission(
    language: 'Japanese',
    bundle: bundle,
    sentenceStats: sentenceStats,
    scenarioStats: scenarioStats,
    swipeStats: swipeStats,
    sentenceRepo: sentenceRepo,
    scenarioRepo: scenarioRepo,
    swipeRepo: swipeRepo,
  );
  final chinese = _buildLanguageMission(
    language: 'Chinese',
    bundle: bundle,
    sentenceStats: sentenceStats,
    scenarioStats: scenarioStats,
    swipeStats: swipeStats,
    sentenceRepo: sentenceRepo,
    scenarioRepo: scenarioRepo,
    swipeRepo: swipeRepo,
  );

  var globalKnown = 0;
  var globalTotal = 0;
  for (final lang in kDictionaryLanguages) {
    globalKnown += swipeRepo.languageKnownCount(
      language: lang,
      bundle: bundle,
      stats: swipeStats,
    );
    globalTotal += swipeRepo.languageTotalCount(
      language: lang,
      bundle: bundle,
    );
  }

  final languageMission = switch (selectedLanguage) {
    'Japanese' => japanese,
    'Chinese' => chinese,
    _ => english,
  };

  return MyPagePassportReport(
    selectedLanguage: selectedLanguage,
    overallFlightProgress: languageMission.overallPercent / 100,
    languageMission: languageMission,
    titleBadges: _buildTitleBadges(
      english: english,
      japanese: japanese,
      chinese: chinese,
      globalSwipeComplete: _isGlobalSwipeComplete(
        known: globalKnown,
        total: globalTotal,
      ),
      anyChapterCleared: _hasAnyChapterCleared(
        bundle: bundle,
        sentenceStats: sentenceStats,
        scenarioStats: scenarioStats,
        swipeStats: swipeStats,
        sentenceRepo: sentenceRepo,
        scenarioRepo: scenarioRepo,
      ),
    ),
  );
});
