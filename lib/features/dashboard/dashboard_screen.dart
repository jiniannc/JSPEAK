
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dashboard_providers.dart';
import '../../app/learning_hub_language_provider.dart';
import '../../app/learning_providers.dart';
import '../../app/providers.dart';
import '../../app/sentence_progress_providers.dart';
import '../../app/shell_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/theme/animated_language_scope.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../shared/widgets/cascade_entrance.dart';
import '../../shared/widgets/flip_reveal_entrance.dart';
import '../../shared/widgets/glass_surface.dart';
import '../shell/floating_island_nav_bar.dart';
import '../shell/main_shell_tab_header.dart';
import 'widgets/continue_learning_card.dart';
import 'widgets/crew_check_in_banner.dart';
import 'widgets/home_todays_pick_card.dart';
import 'widgets/new_update_scenario_card.dart';

/// 홈/대시보드 — 슬레이트 글래스모피즘 UI.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = Active5Layout.of(context);
    final language = ref.watch(learningHubLanguageProvider);
    final dashboardAsync = ref.watch(dashboardProvider);
    final entranceEpoch = ref.watch(homeEntranceEpochProvider);
    final recommended = ref.watch(homeDailySentenceProvider);
    ref.watch(homeDailySentenceAudioPrefetchProvider);

    return DeviceScaffold(
      safeAreaBottom: false,
      safeAreaTop: false,
      backgroundColor: Colors.transparent,
      body: MainShellTabBody(
        child: AnimatedLanguageScope(
          language: language,
          builder: (context, palette) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: dashboardAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('대시보드 로드 실패: $e')),
                  data: (data) {
                    final flightNumber = recommended == null
                        ? '—'
                        : DashboardData.flightNumberFor(recommended);

                    final pickCard = recommended == null
                        ? const _DashboardEmptyCard(
                            message: '콘텐츠 동기화 후\n오늘의 문장이 표시됩니다.',
                          )
                        : HomeTodaysPickCard(
                            sentence: recommended,
                            flightNumber: flightNumber,
                            accent: palette.accent,
                            onStartLearning: () {
                              selectLearningLanguage(
                                ref,
                                recommended.language,
                              );
                              ref
                                  .read(
                                    basicSentenceLanguageProvider.notifier,
                                  )
                                  .set(recommended.language);
                              context.push(
                                '/scenarios/sentences/play'
                                '?lang=${Uri.encodeComponent(recommended.language)}'
                                '&category=${Uri.encodeComponent(recommended.category)}'
                                '&sentenceId=${Uri.encodeComponent(recommended.id)}',
                              );
                            },
                            onListen: recommended.audioUrl.isEmpty
                                ? null
                                : () => ref
                                      .read(audioProvider.notifier)
                                      .toggle(recommended),
                          );

                    return SingleChildScrollView(
                      clipBehavior: Clip.none,
                      padding: metrics.pagePadding.copyWith(
                        bottom:
                            metrics.pagePadding.bottom +
                            FloatingIslandNavBar.scrollBottomPadding(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CascadeEntrance(
                            replayToken: entranceEpoch,
                            delay: Duration.zero,
                            child: const CrewCheckInBanner(),
                          ),
                          const SizedBox(height: 16),
                          if (recommended == null)
                            CascadeEntrance(
                              replayToken: entranceEpoch,
                              delay: const Duration(milliseconds: 80),
                              child: pickCard,
                            )
                          else
                            FlipRevealEntrance(
                              replayToken: entranceEpoch,
                              delay: const Duration(milliseconds: 80),
                              back: const TodaysPickTicketBack(),
                              child: pickCard,
                            ),
                          const SizedBox(height: 16),
                          CascadeEntrance(
                            replayToken: entranceEpoch,
                            delay: const Duration(milliseconds: 160),
                            child: const ContinueLearningCard(),
                          ),
                          const SizedBox(height: 16),
                          CascadeEntrance(
                            replayToken: entranceEpoch,
                            delay: const Duration(milliseconds: 240),
                            child: const NewUpdateScenarioCard(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyCard extends StatelessWidget {
  final String message;

  const _DashboardEmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: GlassSurfaceStyle.subtitleColor,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
