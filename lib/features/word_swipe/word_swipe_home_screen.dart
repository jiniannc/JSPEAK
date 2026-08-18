import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/guide_dismiss_providers.dart';
import '../../app/providers.dart';
import '../../app/swipe_progress_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/language_palette.dart';
import '../../core/utils/relative_time.dart';
import '../../data/datasources/local/swipe_progress_local_datasource.dart';
import '../../data/models/content_chapter.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../shell/floating_island_nav_bar.dart';
import '../../features/learning/widgets/mode_guide_cards.dart';
import '../../shared/widgets/learning_chapter_card_shell.dart';
import 'word_swipe_training_screen.dart';

/// 단어 스와이프 모드 홈 — 고정 글래스 진도 + 주제 카드 리스트.
class WordSwipeHomeScreen extends ConsumerWidget {
  const WordSwipeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(swipeLanguageProvider);
    final progressState = ref.watch(swipeProgressProvider);
    final contentAsync = ref.watch(contentProvider);
    final metrics = Active5Layout.of(context);
    final inset = metrics.pagePadding.left;
    final repo = ref.watch(swipeProgressRepositoryProvider);
    final guideDismiss = ref.watch(guideDismissProvider);

    return contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (content) {
          final bundle = content.bundle;
          final chapters = bundle.wordChaptersFor(language);
          final percent = repo.languageProgressPercent(
            language: language,
            bundle: bundle,
            stats: progressState.stats,
          );
          final known = repo.languageKnownCount(
            language: language,
            bundle: bundle,
            stats: progressState.stats,
          );
          final total = repo.languageTotalCount(
            language: language,
            bundle: bundle,
          );

          final palette = LanguagePalette.forLanguage(language);

          return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 0),
                    child: _GlassProgressPanel(
                      languageLabel: languageLabel(language),
                      percent: percent,
                      completed: known,
                      total: total,
                      accentColor: palette.primary,
                    ),
                  ),
                  if (!guideDismiss.loading && !guideDismiss.wordSwipe)
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 10, inset, 0),
                      child: WordSwipeModeGuideCard(
                        onDismiss: () => ref
                            .read(guideDismissProvider.notifier)
                            .dismissWordSwipe(),
                      ),
                    ),
                  // 스크롤 리스트
                  Expanded(
                    child: chapters.isEmpty
                        ? const Center(
                            child: Text(
                              '이 언어의 단어 데이터가 아직 없어요.\n콘텐츠 동기화 후 다시 시도해 주세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: DashboardPalette.textMuted,
                                height: 1.5,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              inset,
                              18,
                              inset,
                              28 + FloatingIslandNavBar.scrollBottomPadding(context),
                            ),
                            itemCount: chapters.length + 1,
                            separatorBuilder: (context, index) {
                              if (index == 0) {
                                return const SizedBox(height: 12);
                              }
                              return const SizedBox(height: 10);
                            },
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '📚 주제별 훈련 코스',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                          color: Color(0xFF9AA3B2),
                                        ),
                                      ),
                                    ),
                                    if (!guideDismiss.loading &&
                                        guideDismiss.wordSwipe)
                                      ModeGuideReopenButton(
                                        compact: true,
                                        accent: palette.primary,
                                        onPressed: () => ref
                                            .read(guideDismissProvider.notifier)
                                            .restoreWordSwipe(),
                                      ),
                                  ],
                                );
                              }
                              final chapter = chapters[index - 1];
                              final category = chapter.name;
                              final words =
                                  bundle.wordsFor(language, category);
                              final progress = progressState.stats
                                  .forCategory(language, category);
                              return _SwipeCategoryCard(
                                chapter: chapter,
                                wordCount: words.length,
                                progress: progress,
                                onPlay: () {
                                  if (words.isEmpty) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '이 주제에 복습할 단어가 없어요.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  context.push(
                                    '/scenarios/swipe/play',
                                    extra: WordSwipeArgs(
                                      language: language,
                                      category: category,
                                    ),
                                  );
                                },
                                onReview: !progress.played ||
                                        progress.unknownCount == 0
                                    ? null
                                    : () {
                                        context.push(
                                          '/scenarios/swipe/play',
                                          extra: WordSwipeArgs(
                                            language: language,
                                            category: category,
                                            reviewOnly: true,
                                          ),
                                        );
                                      },
                              );
                            },
                          ),
                  ),
                ],
            );
        },
      );
  }
}

/// 상단 고정 — 카드가 아닌 글래스 진도 패널.
class _GlassProgressPanel extends StatelessWidget {
  final String languageLabel;
  final double percent;
  final int completed;
  final int total;
  final Color accentColor;

  const _GlassProgressPanel({
    required this.languageLabel,
    required this.percent,
    required this.completed,
    required this.total,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final rounded = percent.round();
    final value = total == 0 ? 0.0 : (percent / 100).clamp(0.0, 1.0);
    final palette = context.languagePalette ?? LanguagePalette.english;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: palette.glassCardDecoration(
            radius: 16,
            fillAlpha: 0.55,
            borderAlpha: 0.5,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$rounded',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: -0.8,
                      height: 1,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$languageLabel 훈련 완료',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: DashboardPalette.navy,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    '$completed / $total',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: DashboardPalette.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 3.5,
                  backgroundColor: accentColor.withValues(alpha: 0.12),
                  color: accentColor.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeCategoryCard extends StatelessWidget {
  /// 안다 = 청록, 모른다 = 다홍 — 범례·리뷰 버튼 공통.
  static const Color knownColor = DashboardPalette.teal;
  static const Color unknownColor = Color(0xFFE53935);

  final ContentChapter chapter;
  final int wordCount;
  final SwipeCategoryProgress progress;
  final VoidCallback onPlay;
  final VoidCallback? onReview;

  const _SwipeCategoryCard({
    required this.chapter,
    required this.wordCount,
    required this.progress,
    required this.onPlay,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final mastered = progress.isMastered;
    final played = progress.played;
    final known = progress.knownCount.clamp(0, wordCount);
    final unknown = progress.unknownCount;
    final total = progress.totalCount > 0 ? progress.totalCount : wordCount;

    return LearningChapterCardShell(
      chapter: chapter,
      onTap: onPlay,
      thumbnailFallback: Icons.style_rounded,
      headerTrailing: mastered
          ? const LearningChapterMasterBadge()
          : Icon(
              Icons.chevron_right_rounded,
              color: DashboardPalette.textMuted.withValues(
                alpha: played ? 0.55 : 0.35,
              ),
            ),
      content: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, played ? 8 : 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LearningChapterSubtitle(
                      mastered: mastered,
                      text: played
                          ? (mastered
                              ? '이 챕터의 단어 $total개를 모두 마스터했어요!'
                              : '안다 $known · 모른다 $unknown / 전체 $total')
                          : '단어 $wordCount개 · 아직 시작 전',
                    ),
                    if (played && !mastered) ...[
                      const SizedBox(height: 8),
                      _KnowUnknownBar(
                        known: known,
                        unknown: unknown,
                        total: total,
                      ),
                    ],
                    if (mastered) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          value: 1,
                          minHeight: 7,
                          backgroundColor: Color(0xFFFFECB3),
                          color: Color(0xFFFFC107),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (played) ...[
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: DashboardPalette.borderLight.withValues(alpha: 0.9),
              ),
              _ReviewChip(
                mastered: mastered,
                unknown: unknown,
                total: total,
                lastStudiedAt: progress.lastStudiedAt,
                onTap: onReview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KnowUnknownBar extends StatelessWidget {
  final int known;
  final int unknown;
  final int total;

  const _KnowUnknownBar({
    required this.known,
    required this.unknown,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final knownRatio = known / safeTotal;
    final unknownRatio = unknown / safeTotal;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: (knownRatio * 1000).round().clamp(0, 1000),
                  child: const ColoredBox(color: _SwipeCategoryCard.knownColor),
                ),
                Expanded(
                  flex: (unknownRatio * 1000).round().clamp(0, 1000),
                  child: const ColoredBox(
                    color: _SwipeCategoryCard.unknownColor,
                  ),
                ),
                Expanded(
                  flex: ((1 - knownRatio - unknownRatio) * 1000)
                      .round()
                      .clamp(0, 1000),
                  child: const ColoredBox(color: Color(0xFFE8ECF0)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        const Row(
          children: [
            _LegendDot(color: _SwipeCategoryCard.knownColor, label: '안다'),
            SizedBox(width: 10),
            _LegendDot(color: _SwipeCategoryCard.unknownColor, label: '모른다'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: DashboardPalette.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ReviewChip extends StatelessWidget {
  final bool mastered;
  final int unknown;
  final int total;
  final DateTime? lastStudiedAt;
  final VoidCallback? onTap;

  const _ReviewChip({
    required this.mastered,
    required this.unknown,
    required this.total,
    required this.lastStudiedAt,
    required this.onTap,
  });

  Widget? _studiedLabel() {
    final text = formatRelativeStudiedAt(lastStudiedAt);
    if (text.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
          height: 1.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 최소 터치 타겟 확보 (본체 InkWell과 분리)
    const chipWidth = 72.0;
    final studied = _studiedLabel();

    if (mastered) {
      return SizedBox(
        width: chipWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                border: Border.all(
                  color: const Color(0xFFFFC107),
                  width: 2.5,
                ),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFF57F17),
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '완료!',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF57F17),
              ),
            ),
            ?studied,
          ],
        ),
      );
    }

    // 도넛: 모르는 비율을 다홍으로 — “남은 리뷰량” 직관
    final unknownRatio = total <= 0 ? 0.0 : (unknown / total).clamp(0.0, 1.0);
    final canReview = onTap != null && unknown > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canReview ? onTap : null,
        child: SizedBox(
          width: chipWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: unknownRatio,
                      strokeWidth: 4.5,
                      backgroundColor:
                          _SwipeCategoryCard.unknownColor.withValues(alpha: 0.15),
                      color: _SwipeCategoryCard.unknownColor,
                    ),
                    Text(
                      '$unknown',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _SwipeCategoryCard.unknownColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '리뷰',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: canReview
                      ? _SwipeCategoryCard.unknownColor
                      : DashboardPalette.textMuted,
                ),
              ),
              ?studied,
            ],
          ),
        ),
      ),
    );
  }
}
