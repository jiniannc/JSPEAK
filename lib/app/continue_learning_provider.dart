import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/labels.dart';
import '../data/datasources/local/scenario_progress_local_datasource.dart';
import '../data/datasources/local/sentence_progress_local_datasource.dart';
import '../data/datasources/local/swipe_progress_local_datasource.dart';
import '../data/models/content_bundle.dart';
import '../data/models/scenario.dart';
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

  if (content != null && !content.bundle.isEmpty) {
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

/// 사용자가 실제로 "손댄 적 있는" (읽음/시도/듣기/마스터 중 하나라도 기록된)
/// 미완료 카테고리만 "이어서 하기" 대상으로 인정한다.
/// 단순히 마스터되지 않았다는 이유만으로 첫 카테고리를 기본 추천하지 않는다.
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
      // 실제 학습 흔적이 전혀 없는 카테고리는 "이어서 하기" 대상이 아니다.
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

    // 시나리오는 완료 여부만 기록되므로, 이 언어에서 완료한 시나리오가
    // 하나도 없다면 "이어서 하기"가 아니라 첫 학습 시작일 뿐이다. 건너뛴다.
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
