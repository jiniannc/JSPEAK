import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/learning_hub_language_provider.dart';
import '../../app/providers.dart';
import '../../app/scenario_providers.dart';
import '../../app/sentence_progress_providers.dart';
import '../../app/swipe_progress_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../data/models/content_bundle.dart';
import '../../data/models/learning_hub_chapter.dart';
import '../../data/repositories/sentence_progress_repository.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../shell/floating_island_nav_bar.dart';
import '../../shared/widgets/cascade_entrance.dart';
import 'widgets/learning_hub_chapter_card.dart';
import 'widgets/learning_hub_guide_strip.dart';

/// 학습 탭 메인 — 비행 단계별 허브 카드에서 3모드로 진입.
class LearningHomeScreen extends ConsumerStatefulWidget {
  const LearningHomeScreen({super.key});

  @override
  ConsumerState<LearningHomeScreen> createState() =>
      _LearningHomeScreenState();
}

class _LearningHomeScreenState extends ConsumerState<LearningHomeScreen> {
  bool _guideVisible = false;

  @override
  Widget build(BuildContext context) {
    final metrics = Active5Layout.of(context);
    final inset = metrics.pagePadding.left;
    final language = ref.watch(learningHubLanguageProvider);
    final contentAsync = ref.watch(contentProvider);
    final sentenceProgress = ref.watch(sentenceProgressProvider);
    final swipeProgress = ref.watch(swipeProgressProvider);
    final scenarioProgress = ref.watch(scenarioProgressProvider);
    final sentenceRepo = ref.watch(sentenceProgressRepositoryProvider);

    return contentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('학습 화면 로드 실패: $e')),
      data: (content) {
        final bundle = content.bundle;
        final chapters = bundle.learningHubChaptersFor(language);
        final completedChapters = _countCompletedHubChapters(
          chapters: chapters,
          language: language,
          bundle: bundle,
          sentenceProgress: sentenceProgress,
          swipeProgress: swipeProgress,
          scenarioProgress: scenarioProgress,
          sentenceRepo: sentenceRepo,
        );

            return ListView(
                padding: EdgeInsets.fromLTRB(
            inset,
                  0,
            inset,
                  28 + FloatingIslandNavBar.scrollBottomPadding(context),
                ),
                children: [
            CascadeEntrance(
              child: _LearningHubSectionHeader(
                totalChapters: chapters.length,
                completedChapters: completedChapters,
                onGuideTap: () => setState(() => _guideVisible = !_guideVisible),
              ),
            ),
            if (_guideVisible) ...[
              const SizedBox(height: 10),
              LearningHubGuideStrip(
                onDismiss: () => setState(() => _guideVisible = false),
              ),
            ],
            const SizedBox(height: 8),
            if (chapters.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    '이 언어의 학습 데이터가 아직 없어요.\n콘텐츠 동기화 후 다시 시도해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: DashboardPalette.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            else
              for (var i = 0; i < chapters.length; i++) ...[
                  CascadeEntrance(
                  delay: Duration(milliseconds: 80 + i * 50),
                  child: _HubChapterCardLoader(
                    chapter: chapters[i],
                    language: language,
                    bundle: bundle,
                    sentenceProgress: sentenceProgress,
                    swipeProgress: swipeProgress,
                    scenarioProgress: scenarioProgress,
                    sentenceRepo: sentenceRepo,
                    showTapHint: i == 0,
                  ),
                ),
                if (i < chapters.length - 1) const SizedBox(height: 16),
              ],
                ],
              );
          },
        );
  }
}

int _countCompletedHubChapters({
  required List<LearningHubChapter> chapters,
  required String language,
  required ContentBundle bundle,
  required SentenceProgressState sentenceProgress,
  required SwipeProgressState swipeProgress,
  required ScenarioProgressState scenarioProgress,
  required SentenceProgressRepository sentenceRepo,
}) {
  var completed = 0;

  for (final chapter in chapters) {
    final category = chapter.name;
    final words = bundle.wordsFor(language, category);
    final sentences = bundle.sentencesFor(language, category);
    final scenarios = bundle.scenariosForHubChapter(language, chapter);
    final swipeCat = swipeProgress.stats.forCategory(language, category);
    final sentenceSummary = sentences.isEmpty
        ? null
        : sentenceRepo.categorySummary(
            sentences: sentences,
            stats: sentenceProgress.stats,
          );

    bool isScenarioCompleted(String id) =>
        scenarioProgress.stats.isCompleted(language, id);

    final wordDone = LearningHubChapterCard.isWordModeComplete(
      words.length,
      words.isEmpty ? null : swipeCat,
    );
    final sentenceDone = LearningHubChapterCard.isSentenceModeComplete(
      sentenceSummary,
    );
    final scenarioDone = LearningHubChapterCard.isScenarioModeComplete(
      scenarios,
      isScenarioCompleted,
    );

    if (wordDone && sentenceDone && scenarioDone) {
      completed++;
    }
  }

  return completed;
}

class _LearningHubSectionHeader extends StatelessWidget {
  final int totalChapters;
  final int completedChapters;
  final VoidCallback onGuideTap;

  const _LearningHubSectionHeader({
    required this.totalChapters,
    required this.completedChapters,
    required this.onGuideTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '기내대화 커리큘럼',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$completedChapters/$totalChapters 완료',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0284C7),
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onGuideTap,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                '✨ 학습 가이드',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HubChapterCardLoader extends StatelessWidget {
  final LearningHubChapter chapter;
  final String language;
  final ContentBundle bundle;
  final SentenceProgressState sentenceProgress;
  final SwipeProgressState swipeProgress;
  final ScenarioProgressState scenarioProgress;
  final SentenceProgressRepository sentenceRepo;
  final bool showTapHint;

  const _HubChapterCardLoader({
    required this.chapter,
    required this.language,
    required this.bundle,
    required this.sentenceProgress,
    required this.swipeProgress,
    required this.scenarioProgress,
    required this.sentenceRepo,
    this.showTapHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final category = chapter.name;
    final words = bundle.wordsFor(language, category);
    final sentences = bundle.sentencesFor(language, category);
    final scenarios = bundle.scenariosForHubChapter(language, chapter);
    final swipeCat = swipeProgress.stats.forCategory(language, category);
    final sentenceSummary = sentenceRepo.categorySummary(
      sentences: sentences,
      stats: sentenceProgress.stats,
    );

    bool isScenarioCompleted(String id) =>
        scenarioProgress.stats.isCompleted(language, id);

    return LearningHubChapterCard(
      chapter: chapter,
      language: language,
      wordCount: words.length,
      showTapHint: showTapHint,
      swipeProgress: words.isEmpty ? null : swipeCat,
      sentenceSummary: sentences.isEmpty ? null : sentenceSummary,
      scenarios: scenarios,
      isScenarioCompleted: isScenarioCompleted,
      onWordPlay: words.isEmpty
          ? null
          : () => openWordSwipeFromHub(
                context,
                language: language,
                category: category,
              ),
      onWordReview: !swipeCat.played || swipeCat.unknownCount == 0
          ? null
          : () => openWordSwipeFromHub(
                context,
                language: language,
                category: category,
                reviewOnly: true,
              ),
      onSentencePlay: sentences.isEmpty
          ? null
          : () => openSentenceTrainingFromHub(
                context,
                language: language,
                category: category,
              ),
    );
  }
}
