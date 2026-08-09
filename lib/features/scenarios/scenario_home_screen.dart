import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/guide_dismiss_providers.dart';
import '../../app/providers.dart';
import '../../app/scenario_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/language_palette.dart';
import '../../data/models/scenario.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../features/learning/widgets/mode_guide_cards.dart';
import 'widgets/scenario_card.dart';
import 'widgets/scenario_chapter_list.dart';

/// 상황별 시나리오 훈련 — 챕터 커리큘럼 아코디언.
class ScenarioHomeScreen extends ConsumerWidget {
  const ScenarioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(scenarioLanguageProvider);
    final chapters = ref.watch(scenarioChapterListProvider);
    final progressState = ref.watch(scenarioProgressProvider);
    final contentAsync = ref.watch(contentProvider);
    final metrics = Active5Layout.of(context);
    final horizontalInset = metrics.pagePadding.left;
    final guideDismiss = ref.watch(guideDismissProvider);

    final repo = ref.watch(scenarioProgressRepositoryProvider);
    final percent = repo.progressPercent(
      language: language,
      scenarios: contentAsync.value?.bundle.scenarios ?? [],
      stats: progressState.stats,
    );
    final completed = repo.completedCount(
      language: language,
      scenarios: contentAsync.value?.bundle.scenarios ?? [],
      stats: progressState.stats,
    );
    final total = repo.totalCount(
      language: language,
      scenarios: contentAsync.value?.bundle.scenarios ?? [],
    );

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (_) {
        final palette = LanguagePalette.forLanguage(language);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 0),
              child: ScenarioProgressHeader(
                languageLabel: languageLabel(language),
                percent: percent,
                completed: completed,
                total: total,
                accentColor: palette.primary,
                margin: const EdgeInsets.only(bottom: 8),
              ),
            ),
            if (!guideDismiss.loading && !guideDismiss.scenario)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  0,
                  horizontalInset,
                  8,
                ),
                child: ScenarioModeGuideCard(
                  onDismiss: () =>
                      ref.read(guideDismissProvider.notifier).dismissScenario(),
                ),
              ),
            Expanded(
              child: chapters.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '시나리오 데이터가 없습니다.\n콘텐츠 동기화 후 다시 시도해 주세요.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: DashboardPalette.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: metrics.pagePadding.copyWith(
                        top: 4,
                        bottom: 16 + MediaQuery.paddingOf(context).bottom,
                      ),
                      itemCount: chapters.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final chapterCompleted = chapter.scenarios
                            .where(
                              (s) => progressState.stats.isCompleted(
                                language,
                                s.id,
                              ),
                            )
                            .length;

                        return ScenarioChapterExpansionCard(
                          chapter: chapter,
                          completedCount: chapterCompleted,
                          isCompleted: (id) =>
                              progressState.stats.isCompleted(language, id),
                          onScenarioTap: (scenario) => _openScenario(
                            context,
                            scenario,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openScenario(BuildContext context, Scenario scenario) {
    context.go(
      '/scenarios/train/${scenario.id}',
      extra: scenario,
    );
  }
}
