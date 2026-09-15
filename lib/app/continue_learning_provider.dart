import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/labels.dart';
import '../data/datasources/local/last_learning_session_local_datasource.dart';
import '../data/datasources/local/scenario_progress_local_datasource.dart';
import '../data/datasources/local/sentence_progress_local_datasource.dart';
import '../data/datasources/local/swipe_progress_local_datasource.dart';
import '../data/models/content_bundle.dart';
import '../data/models/scenario.dart';
import '../data/models/sentence.dart';
import 'last_learning_session_providers.dart';
import 'providers.dart';
import 'scenario_providers.dart';
import 'sentence_progress_providers.dart';
import 'swipe_progress_providers.dart';

enum ContinueLearningKind {
  wordSwipe,
  basicSentence,
  scenario,
  learningHub,
}

/// 홈 "이어서 학습하기" 카드에 표시할 최근 학습 대상.
class ContinueLearningTarget {
  final ContinueLearningKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final String language;
  final String? category;
  final Scenario? scenario;
  final bool reviewOnly;
  final int completed;
  final int total;
  final int? swipeCardIndex;
  final List<String> swipeUnknownWordIds;
  final String? sentenceId;
  final int? scenarioLineIndex;

  const ContinueLearningTarget({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.language,
    this.category,
    this.scenario,
    this.reviewOnly = false,
    this.completed = 0,
    this.total = 0,
    this.swipeCardIndex,
    this.swipeUnknownWordIds = const [],
    this.sentenceId,
    this.scenarioLineIndex,
  });

  bool get hasProgress => total > 0;

  double get progressRatio =>
      total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

  int get progressPercent => (progressRatio * 100).round();

  /// 카드에 학습 모드를 명확히 구분해 보여주기 위한 짧은 라벨.
  String get modeLabel => switch (kind) {
        ContinueLearningKind.wordSwipe => '단어 스와이프',
        ContinueLearningKind.basicSentence => '기본 문장',
        ContinueLearningKind.scenario => '시나리오',
        ContinueLearningKind.learningHub => '추천',
      };
}

final continueLearningProvider = Provider<ContinueLearningTarget>((ref) {
  final content = ref.watch(contentProvider).value;
  final swipeStats = ref.watch(swipeProgressProvider).stats;
  final sentenceStats = ref.watch(sentenceProgressProvider).stats;
  final scenarioProgress = ref.watch(scenarioProgressProvider);
  final lastSession = ref.watch(lastLearningSessionProvider);

  if (content != null && !content.bundle.isEmpty) {
    if (lastSession != null) {
      final fromSession = _targetFromLastSession(
        session: lastSession,
        bundle: content.bundle,
        swipeStats: swipeStats,
        sentenceStats: sentenceStats,
        scenarioStats: scenarioProgress.stats,
      );
      if (fromSession != null) {
        return fromSession;
      }
    }

    final swipe = _latestSwipeTarget(swipeStats);
    if (swipe != null) {
      return swipe;
    }

    final sentence = _firstIncompleteSentenceCategory(
      bundle: content.bundle,
      stats: sentenceStats,
    );
    if (sentence != null) {
      return sentence;
    }

    final scenario = _firstIncompleteScenario(
      bundle: content.bundle,
      stats: scenarioProgress.stats,
    );
    if (scenario != null) {
      return scenario;
    }
  }

  return const ContinueLearningTarget(
    kind: ContinueLearningKind.learningHub,
    title: '아직 진행 중인 학습이 없어요',
    subtitle: '학습 모드로 들어가 첫 학습을 시작해 보세요',
    icon: Icons.flight_class_rounded,
    language: 'English',
  );
});

ContinueLearningTarget? _targetFromLastSession({
  required LastLearningSession session,
  required ContentBundle bundle,
  required SwipeProgressStats swipeStats,
  required SentenceProgressStats sentenceStats,
  required ScenarioProgressStats scenarioStats,
}) {
  switch (session.mode) {
    case LastLearningMode.wordSwipe:
      return _wordSwipeTargetFromSession(session, bundle, swipeStats);
    case LastLearningMode.basicSentence:
      return _basicSentenceTargetFromSession(session, bundle, sentenceStats);
    case LastLearningMode.scenario:
      return _scenarioTargetFromSession(session, bundle, scenarioStats);
  }
}

ContinueLearningTarget? _wordSwipeTargetFromSession(
  LastLearningSession session,
  ContentBundle bundle,
  SwipeProgressStats swipeStats,
) {
  final category = session.category?.trim();
  if (category == null || category.isEmpty) return null;
  if (!bundle.categoriesFor(session.language).contains(category)) {
    return null;
  }

  final progress = swipeStats.forCategory(session.language, category);
  final reviewOnly =
      session.reviewOnly || (progress.played && progress.unknownCount > 0);

  return ContinueLearningTarget(
    kind: ContinueLearningKind.wordSwipe,
    title: category,
    subtitle: reviewOnly
        ? '${languageLabel(session.language)} · 복습 모드'
        : languageLabel(session.language),
    icon: Icons.swipe_rounded,
    language: session.language,
    category: category,
    reviewOnly: reviewOnly,
    completed: progress.knownCount,
    total: progress.totalCount,
    swipeCardIndex: session.cardIndex,
    swipeUnknownWordIds: session.unknownWordIds,
  );
}

ContinueLearningTarget? _basicSentenceTargetFromSession(
  LastLearningSession session,
  ContentBundle bundle,
  SentenceProgressStats sentenceStats,
) {
  final category = session.category?.trim();
  if (category == null || category.isEmpty) return null;

  final sentences = bundle.sentencesFor(session.language, category);
  if (sentences.isEmpty) return null;

  var masteredCount = 0;
  var touchedCount = 0;
  for (final sentence in sentences) {
    final progress = sentenceStats.forSentence(sentence.id);
    if (progress.isRead ||
        progress.isAttempted ||
        progress.isMastered ||
        progress.hasListened) {
      touchedCount += 1;
    }
    if (progress.isMastered) masteredCount += 1;
  }
  if (touchedCount == 0) return null;

  final sentenceId = _resolveSentenceId(session.sentenceId, sentences);

  return ContinueLearningTarget(
    kind: ContinueLearningKind.basicSentence,
    title: category,
    subtitle: languageLabel(session.language),
    icon: Icons.format_quote_rounded,
    language: session.language,
    category: category,
    completed: masteredCount,
    total: sentences.length,
    sentenceId: sentenceId,
  );
}

ContinueLearningTarget? _scenarioTargetFromSession(
  LastLearningSession session,
  ContentBundle bundle,
  ScenarioProgressStats scenarioStats,
) {
  final scenarioId = session.scenarioId?.trim();
  if (scenarioId == null || scenarioId.isEmpty) return null;

  Scenario? scenario;
  for (final candidate in bundle.scenarios) {
    if (candidate.id == scenarioId && !candidate.isSheetHeaderRow) {
      scenario = candidate;
      break;
    }
  }
  if (scenario == null) return null;
  if (scenarioStats.isCompleted(scenario.language, scenario.id)) return null;

  final scenarios = bundle
      .scenariosFor(scenario.language)
      .where((Scenario s) => !s.isSheetHeaderRow)
      .toList();
  final completedCount =
      scenarios.where((s) => scenarioStats.isCompleted(scenario!.language, s.id)).length;

  return ContinueLearningTarget(
    kind: ContinueLearningKind.scenario,
    title: scenario.title,
    subtitle: languageLabel(scenario.language),
    icon: Icons.theater_comedy_outlined,
    language: scenario.language,
    scenario: scenario,
    completed: completedCount,
    total: scenarios.length,
    scenarioLineIndex: session.scenarioLineIndex,
  );
}

String? _resolveSentenceId(String? savedId, List<Sentence> sentences) {
  if (savedId != null && savedId.isNotEmpty) {
    for (final sentence in sentences) {
      if (sentence.id == savedId) return savedId;
    }
  }
  return sentences.isNotEmpty ? sentences.first.id : null;
}

ContinueLearningTarget? _latestSwipeTarget(SwipeProgressStats stats) {
  DateTime? latestAt;
  String? language;
  String? category;
  var reviewOnly = false;

  for (final entry in stats.byKey.entries) {
    final progress = entry.value;
    if (!progress.played || progress.lastStudiedAt == null) continue;
    final at = progress.lastStudiedAt!;
    if (latestAt != null && !at.isAfter(latestAt)) continue;

    final pipe = entry.key.indexOf('|');
    if (pipe <= 0) continue;

    latestAt = at;
    language = entry.key.substring(0, pipe);
    category = entry.key.substring(pipe + 1);
    reviewOnly = progress.unknownCount > 0;
  }

  if (language == null || category == null) return null;

  final progress = stats.forCategory(language, category);

  return ContinueLearningTarget(
    kind: ContinueLearningKind.wordSwipe,
    title: category,
    subtitle: reviewOnly
        ? '${languageLabel(language)} · 복습 모드'
        : languageLabel(language),
    icon: Icons.swipe_rounded,
    language: language,
    category: category,
    reviewOnly: reviewOnly,
    completed: progress.knownCount,
    total: progress.totalCount,
  );
}

ContinueLearningTarget? _firstIncompleteSentenceCategory({
  required ContentBundle bundle,
  required SentenceProgressStats stats,
}) {
  for (final lang in ['English', 'Japanese', 'Chinese']) {
    for (final category in bundle.categoriesFor(lang)) {
      final sentences = bundle.sentencesFor(lang, category);
      if (sentences.isEmpty) continue;

      var touchedCount = 0;
      var needsWork = false;
      var masteredCount = 0;
      for (final s in sentences) {
        final p = stats.forSentence(s.id);
        final touched =
            p.isRead || p.isAttempted || p.isMastered || p.hasListened;
        if (touched) touchedCount += 1;
        if (p.isMastered) {
          masteredCount += 1;
        } else {
          needsWork = true;
        }
      }
      if (touchedCount == 0 || !needsWork) continue;

      return ContinueLearningTarget(
        kind: ContinueLearningKind.basicSentence,
        title: category,
        subtitle: languageLabel(lang),
        icon: Icons.format_quote_rounded,
        language: lang,
        category: category,
        completed: masteredCount,
        total: sentences.length,
      );
    }
  }
  return null;
}

ContinueLearningTarget? _firstIncompleteScenario({
  required ContentBundle bundle,
  required ScenarioProgressStats stats,
}) {
  for (final lang in ['English', 'Japanese', 'Chinese']) {
    final scenarios = bundle
        .scenariosFor(lang)
        .where((Scenario s) => !s.isSheetHeaderRow)
        .toList();
    if (scenarios.isEmpty) continue;

    final completedCount =
        scenarios.where((s) => stats.isCompleted(lang, s.id)).length;

    if (completedCount == 0) continue;

    for (final scenario in scenarios) {
      if (stats.isCompleted(lang, scenario.id)) {
        continue;
      }
      return ContinueLearningTarget(
        kind: ContinueLearningKind.scenario,
        title: scenario.title,
        subtitle: languageLabel(lang),
        icon: Icons.theater_comedy_outlined,
        language: lang,
        scenario: scenario,
        completed: completedCount,
        total: scenarios.length,
      );
    }
  }
  return null;
}
