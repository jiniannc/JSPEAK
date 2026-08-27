import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/learning_local_datasource.dart';
import '../data/models/sentence.dart';
import '../data/repositories/learning_repository.dart';
import 'providers.dart';
import 'dictionary_providers.dart';
import 'learning_hub_language_provider.dart';
import 'scenario_providers.dart';

final learningLocalDataSourceProvider = Provider<LearningLocalDataSource>(
  (ref) => LearningLocalDataSource(),
);

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return LearningRepository(
    local: ref.watch(learningLocalDataSourceProvider),
  );
});

/// 대시보드에 표시할 학습 요약.
class DashboardData {
  static const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  final double flightProgress;
  final List<bool> weeklyStreak;
  final int todayWeekdayIndex;
  final int practicedCount;
  final int totalSentenceCount;
  final double scenarioOverallProgress;
  final List<LanguageProgressSummary> scenarioLanguageProgress;
  final int consecutiveStreak;

  const DashboardData({
    this.flightProgress = 0,
    this.weeklyStreak = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    this.todayWeekdayIndex = 0,
    this.practicedCount = 0,
    this.totalSentenceCount = 0,
    this.scenarioOverallProgress = 0,
    this.scenarioLanguageProgress = const [],
    this.consecutiveStreak = 0,
  });

  static String flightNumberFor(Sentence sentence) {
    final prefix = switch (sentence.language) {
      'English' => 'LJ',
      'Japanese' => 'JL',
      'Chinese' => 'CA',
      _ => 'JS',
    };
    final number = 100 + (sentence.id.hashCode % 899).abs();
    return '$prefix $number';
  }

  static String seatClassFor(Sentence sentence) =>
      sentence.category.isNotEmpty ? sentence.category : sentence.language;
}

class DashboardController extends AsyncNotifier<DashboardData> {
  LearningRepository get _learning => ref.read(learningRepositoryProvider);

  @override
  Future<DashboardData> build() async {
    final content = await ref.watch(contentProvider.future);
    final stats = await _learning.loadStats();
    final scenarioProgress = ref.watch(scenarioProgressProvider);
    final scenarioRepo = ref.read(scenarioProgressRepositoryProvider);
    final today = DateTime.now();

    final bundle = content.bundle;
    final progress = _learning.progressRatio(stats, bundle);

    final validIds = bundle.sentences.map((s) => s.id).toSet();
    final practiced =
        stats.practicedSentenceIds.where(validIds.contains).length;

    final scenarios = bundle.scenarios;
    final scenarioOverall = scenarioRepo.overallProgressPercent(
      bundle: bundle,
      stats: scenarioProgress.stats,
    );
    final langProgress = kDictionaryLanguages.map((lang) {
      return LanguageProgressSummary(
        language: lang,
        percent: scenarioRepo.progressPercent(
          language: lang,
          scenarios: scenarios,
          stats: scenarioProgress.stats,
        ),
        completed: scenarioRepo.completedCount(
          language: lang,
          scenarios: scenarios,
          stats: scenarioProgress.stats,
        ),
        total: scenarioRepo.totalCount(language: lang, scenarios: scenarios),
      );
    }).toList();

    return DashboardData(
      flightProgress: progress,
      weeklyStreak: weeklyStreakFor(today, stats.completionDates),
      todayWeekdayIndex: today.weekday - DateTime.monday,
      practicedCount: practiced,
      totalSentenceCount: bundle.sentences.length,
      scenarioOverallProgress: scenarioOverall,
      scenarioLanguageProgress: langProgress,
      consecutiveStreak:
          consecutiveStreakFor(today, stats.completionDates),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
  DashboardController.new,
);

/// 홈 오늘의 문장 — 상단 언어 스위처와 연동 (언어별 3후보 중 1개).
final homeDailySentenceProvider = Provider<Sentence?>((ref) {
  final language = ref.watch(learningHubLanguageProvider);
  final content = ref.watch(contentProvider).value;
  final bundle = content?.bundle;
  if (bundle == null || bundle.isEmpty) return null;

  return ref.read(learningRepositoryProvider).pickDailySentenceForLanguage(
        bundle,
        language,
        DateTime.now(),
      );
});

/// 홈 Today's Pick 오디오 — 카드 표시 전 미리 받아 재생 지연을 줄인다.
final homeDailySentenceAudioPrefetchProvider = Provider<void>((ref) {
  final sentence = ref.watch(homeDailySentenceProvider);
  if (sentence == null || sentence.audioUrl.isEmpty) return;
  ref.read(audioProvider.notifier).prefetch(sentence);
});
