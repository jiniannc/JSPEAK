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

  const MyPagePassportReport({
    required this.selectedLanguage,
    required this.overallFlightProgress,
    required this.languageMission,
  });
}

/// 3개 언어 미션 진행 + 칭호 뱃지 판정에 필요한 원본 신호를 한 번만 계산해 공유.
class MyPageProgressSignals {
  final MyPageLanguageMissionProgress english;
  final MyPageLanguageMissionProgress japanese;
  final MyPageLanguageMissionProgress chinese;
  final int globalSwipeKnown;
  final int globalSwipeTotal;
  final bool anyChapterCleared;

  const MyPageProgressSignals({
    required this.english,
    required this.japanese,
    required this.chinese,
    required this.globalSwipeKnown,
    required this.globalSwipeTotal,
    required this.anyChapterCleared,
  });

  MyPageLanguageMissionProgress missionFor(String language) => switch (language) {
        'Japanese' => japanese,
        'Chinese' => chinese,
        _ => english,
      };
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

final myPageProgressSignalsProvider = Provider<MyPageProgressSignals?>((ref) {
  final content = ref.watch(contentProvider).value;
  if (content == null) return null;

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

  return MyPageProgressSignals(
    english: english,
    japanese: japanese,
    chinese: chinese,
    globalSwipeKnown: globalKnown,
    globalSwipeTotal: globalTotal,
    anyChapterCleared: _hasAnyChapterCleared(
      bundle: bundle,
      sentenceStats: sentenceStats,
      scenarioStats: scenarioStats,
      swipeStats: swipeStats,
      sentenceRepo: sentenceRepo,
      scenarioRepo: scenarioRepo,
    ),
  );
});

final myPagePassportReportProvider = Provider<MyPagePassportReport?>((ref) {
  final signals = ref.watch(myPageProgressSignalsProvider);
  if (signals == null) return null;

  final selectedLanguage = ref.watch(learningHubLanguageProvider);
  final languageMission = signals.missionFor(selectedLanguage);

  return MyPagePassportReport(
    selectedLanguage: selectedLanguage,
    overallFlightProgress: languageMission.overallPercent / 100,
    languageMission: languageMission,
  );
});
