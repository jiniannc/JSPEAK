import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/guide_dismiss_providers.dart';
import '../../app/providers.dart';
import '../../app/sentence_progress_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/language_palette.dart';
import '../../data/repositories/sentence_progress_repository.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../features/learning/widgets/mode_guide_cards.dart';
import 'widgets/achievement_stamps.dart';

/// 기본 문장 학습 홈 — 글래스 진도 + 주제 카드 + 3단계 스탬프.
class BasicSentenceHomeScreen extends ConsumerWidget {
  const BasicSentenceHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(basicSentenceLanguageProvider);
    final progressState = ref.watch(sentenceProgressProvider);
    final contentAsync = ref.watch(contentProvider);
    final metrics = Active5Layout.of(context);
    final inset = metrics.pagePadding.left;
    final repo = ref.watch(sentenceProgressRepositoryProvider);
    final guideDismiss = ref.watch(guideDismissProvider);

    return contentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (content) {
            final bundle = content.bundle;
            final categories = bundle.categoriesFor(language);
            final percent = repo.languageProgressPercent(
              language: language,
              bundle: bundle,
              stats: progressState.stats,
            );
            final attempted = repo.languageAttemptedCount(
              language: language,
              bundle: bundle,
              stats: progressState.stats,
            );
            final total = repo.languageTotalCount(
              language: language,
              bundle: bundle,
            );
            final stamps = repo.languageStampSummary(
              language: language,
              bundle: bundle,
              stats: progressState.stats,
            );

            final palette =
                LanguagePalette.forLanguage(language);

            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 0),
                    child: _SentenceProgressCard(
                      languageLabel: languageLabel(language),
                      percent: percent,
                      completed: attempted,
                      total: total,
                      accentColor: palette.primary,
                      chapterTotal: stamps.total,
                      readCount: stamps.readCount,
                      attemptedCount: stamps.attemptedCount,
                      masteredCount: stamps.masteredCount,
                    ),
                  ),
                  if (!guideDismiss.loading && !guideDismiss.basicSentence)
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 10, inset, 0),
                      child: BasicSentenceModeGuideCard(
                        onDismiss: () => ref
                            .read(guideDismissProvider.notifier)
                            .dismissBasicSentence(),
                      ),
                    ),
                  Expanded(
                    child: categories.isEmpty
                        ? const Center(
                            child: Text(
                              '이 언어의 문장 데이터가 아직 없어요.\n콘텐츠 동기화 후 다시 시도해 주세요.',
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
                              28 + MediaQuery.paddingOf(context).bottom,
                            ),
                            itemCount: categories.length + 1,
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
                                        guideDismiss.basicSentence)
                                      ModeGuideReopenButton(
                                        compact: true,
                                        accent: palette.primary,
                                        onPressed: () => ref
                                            .read(guideDismissProvider.notifier)
                                            .restoreBasicSentence(),
                                      ),
                                  ],
                                );
                              }
                              final category = categories[index - 1];
                              final sentences =
                                  bundle.sentencesFor(language, category);
                              final summary = repo.categorySummary(
                                sentences: sentences,
                                stats: progressState.stats,
                              );
                              return _SentenceCategoryCard(
                                category: category,
                                summary: summary,
                                onTap: () {
                                  if (sentences.isEmpty) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '이 주제에 학습할 문장이 없어요.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  context.push(
                                    '/scenarios/sentences/play'
                                    '?lang=${Uri.encodeComponent(language)}'
                                    '&category=${Uri.encodeComponent(category)}',
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

class _SentenceProgressCard extends StatelessWidget {
  final String languageLabel;
  final double percent;
  final int completed;
  final int total;
  final Color accentColor;
  final int chapterTotal;
  final int readCount;
  final int attemptedCount;
  final int masteredCount;

  const _SentenceProgressCard({
    required this.languageLabel,
    required this.percent,
    required this.completed,
    required this.total,
    required this.accentColor,
    required this.chapterTotal,
    required this.readCount,
    required this.attemptedCount,
    required this.masteredCount,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                      '$languageLabel 문장 훈련 완료',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: DashboardPalette.navy,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StampCountChip(
                      label: '읽기',
                      icon: Icons.menu_book_rounded,
                      count: readCount,
                      total: chapterTotal,
                      ink: const Color(0xFF4A90D9),
                      softBg: const Color(0xFFE8F2FC),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StampCountChip(
                      label: '말하기',
                      icon: Icons.mic_rounded,
                      count: attemptedCount,
                      total: chapterTotal,
                      ink: DashboardPalette.teal,
                      softBg: const Color(0xFFE0F4F4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StampCountChip(
                      label: '마스터',
                      icon: Icons.local_fire_department_rounded,
                      count: masteredCount,
                      total: chapterTotal,
                      ink: const Color(0xFFE67E22),
                      softBg: const Color(0xFFFFF3E0),
                      isGold: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StampCountChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final int total;
  final Color ink;
  final Color softBg;
  final bool isGold;

  const _StampCountChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.total,
    required this.ink,
    required this.softBg,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = count > 0;
    final complete = total > 0 && count >= total;
    final ratio = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);

    // 0%여도 고유색을 아주 옅게 깔아 "채워질 자리" 힌트
    final emptyFill = ink.withValues(alpha: 0.07);
    final emptyBorder = ink.withValues(alpha: 0.18);
    final emptyFg = ink.withValues(alpha: 0.42);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: hasAny ? softBg : emptyFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: complete
              ? ink.withValues(alpha: 0.45)
              : hasAny
                  ? ink.withValues(alpha: 0.22)
                  : emptyBorder,
        ),
        boxShadow: complete
            ? [
                BoxShadow(
                  color: ink.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AchievementStamp(
                label: label,
                icon: icon,
                active: hasAny,
                ink: ink,
                rotation: isGold ? -0.05 : 0.05,
                isGold: isGold,
                size: 22,
                colorHint: !hasAny,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: hasAny ? ink : emptyFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$count',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: hasAny ? ink : emptyFg,
                    height: 1,
                    letterSpacing: -0.4,
                  ),
                ),
                TextSpan(
                  text: ' / $total',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: hasAny
                        ? ink.withValues(alpha: 0.65)
                        : ink.withValues(alpha: 0.32),
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: ' 주제',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: hasAny
                        ? ink.withValues(alpha: 0.55)
                        : ink.withValues(alpha: 0.28),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 2.5,
              backgroundColor: ink.withValues(alpha: hasAny ? 0.12 : 0.1),
              color: ink.withValues(alpha: complete ? 1 : 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceCategoryCard extends StatelessWidget {
  final String category;
  final SentenceCategorySummary summary;
  final VoidCallback onTap;

  const _SentenceCategoryCard({
    required this.category,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mastered = summary.allMastered;
    final started = summary.readCount > 0 ||
        summary.attemptedCount > 0 ||
        summary.masteredCount > 0;
    final total = summary.total;
    final palette = context.languagePalette ?? LanguagePalette.english;

    final BoxDecoration decoration;
    final double opacity;

    if (mastered) {
      opacity = 1;
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFC107).withValues(alpha: 0.55),
          width: 1.4,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF8E1).withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0.7),
            const Color(0xFFFFECB3).withValues(alpha: 0.4),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else if (started) {
      opacity = 1;
      decoration = palette.glassCardDecoration(
        radius: 16,
        fillAlpha: 0.62,
        borderAlpha: 0.48,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );
    } else {
      opacity = 0.8;
      decoration = palette.glassCardDecoration(
        radius: 16,
        fillAlpha: 0.45,
        borderAlpha: 0.38,
        shadows: const [],
      );
    }

    return Opacity(
      opacity: opacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: decoration,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: DashboardPalette.navy,
                                ),
                              ),
                            ),
                            if (mastered) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC107)
                                      .withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'MASTER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                    color: Color(0xFFF57F17),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          mastered
                              ? '이 챕터의 문장 $total개를 모두 마스터했어요!'
                              : started
                                  ? '읽기 ${summary.readCount} · 말하기 ${summary.attemptedCount} · 마스터 ${summary.masteredCount} / 전체 $total개'
                                  : '문장 $total개 · 아직 시작 전',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: mastered
                                ? const Color(0xFFF57F17)
                                : DashboardPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AchievementStampCluster(
                    read: summary.allRead,
                    attempted: summary.allAttempted,
                    mastered: summary.allMastered,
                  ),
                  const SizedBox(width: 2),
                  if (mastered)
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFFF57F17),
                            size: 22,
                          ),
                          Text(
                            '완료!',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF57F17),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: DashboardPalette.textMuted.withValues(alpha: 0.45),
                    ),
                ],
              ),
            ),
          ),
        ),
        ),
        ),
      ),
    );
  }
}
