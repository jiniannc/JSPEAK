import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/learning_tour_providers.dart';
import '../../app/providers.dart';
import '../../app/sentence_progress_providers.dart';
import '../../core/theme/language_palette.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../data/models/sentence.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../features/dictionary/widgets/sentence_wheel_view.dart';
import '../../shared/widgets/score_celebration_overlay.dart';
import '../../features/scenarios/widgets/scenario_glass_header.dart';
import '../../features/learning/widgets/mode_guide_cards.dart';

/// 기본 문장 학습 — 주제별 3D 휠 훈련.
class BasicSentenceTrainingScreen extends ConsumerStatefulWidget {
  final String language;
  final String category;
  final String? initialSentenceId;

  const BasicSentenceTrainingScreen({
    super.key,
    required this.language,
    required this.category,
    this.initialSentenceId,
  });

  @override
  ConsumerState<BasicSentenceTrainingScreen> createState() =>
      _BasicSentenceTrainingScreenState();
}

class _BasicSentenceTrainingScreenState
    extends ConsumerState<BasicSentenceTrainingScreen> {
  int _currentIndex = 0;
  bool _showCelebration = false;

  void _onWheelCompleted() {
    if (_showCelebration || !mounted) return;
    setState(() => _showCelebration = true);
    HapticFeedback.heavyImpact();
    Future.delayed(ScoreCelebrationTier.perfect.duration, () {
      if (mounted) context.pop();
    });
  }

  int _initialIndexFor(List<Sentence> sentences) {
    final targetId = widget.initialSentenceId;
    if (targetId == null || targetId.isEmpty) return 0;
    final index = sentences.indexWhere((s) => s.id == targetId);
    return index >= 0 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(contentProvider);
    final palette = LanguagePalette.forLanguage(widget.language);
    final progressState = ref.watch(sentenceProgressProvider);
    final repo = ref.watch(sentenceProgressRepositoryProvider);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: palette.toColorScheme(),
        extensions: [palette],
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) context.pop();
        },
        child: DeviceScaffold(
          body: contentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (content) {
              final sentences = content.bundle.sentencesFor(
                widget.language,
                widget.category,
              );
              if (sentences.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('문장이 없습니다.'),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('돌아가기'),
                      ),
                    ],
                  ),
                );
              }

              final summary = repo.categorySummary(
                sentences: sentences,
                stats: progressState.stats,
              );
              final startIndex = _initialIndexFor(sentences);
              final progress = sentences.isEmpty
                  ? 0.0
                  : (_currentIndex + 1) / sentences.length;
              final metaLabel =
                  '${widget.category} · ${summary.attemptedCount}/${summary.total} 말하기';

              const headerReserve = 84.0;

              return ColoredBox(
                color: DashboardPalette.softGray,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: headerReserve),
                      child: SentenceWheelView(
                        key: ValueKey(
                          '${widget.language}|${widget.category}|'
                          '${widget.initialSentenceId ?? ''}',
                        ),
                        tourOverlayContext: context,
                        sentences: sentences,
                        initialIndex: startIndex,
                        onIndexChanged: (i) {
                          if (_currentIndex != i) {
                            setState(() => _currentIndex = i);
                          }
                        },
                        onCompleted: _onWheelCompleted,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: ScenarioGlassHeader(
                          progress: progress.clamp(0.0, 1.0),
                          metaLabel: metaLabel,
                          accentColor: palette.primary,
                          onBack: () => context.pop(),
                          onOptions: () {
                            showModalBottomSheet<void>(
                              context: context,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                        Icons.route_rounded,
                                      ),
                                      title: const Text('가이드 다시보기'),
                                      subtitle: const Text(
                                        'In-Flight Briefing Tour',
                                      ),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        ref
                                            .read(
                                              learningTourReplaySignalProvider
                                                  .notifier,
                                            )
                                            .request();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.info_outline_rounded,
                                      ),
                                      title: const Text('스탬프 획득 방법'),
                                      subtitle: const Text(
                                        '귀로 익히기 · 말하기 도전 · 발음 마스터',
                                      ),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        showModalBottomSheet<void>(
                                          context: context,
                                          backgroundColor: Colors.white,
                                          shape:
                                              const RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                          ),
                                          builder: (_) => const SafeArea(
                                            child: Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                16,
                                                8,
                                                16,
                                                20,
                                              ),
                                              child:
                                                  BasicSentenceModeGuideCard(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.exit_to_app_rounded,
                                      ),
                                      title: const Text('학습 종료'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        context.pop();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_showCelebration)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: ScoreCelebrationOverlay(
                            tier: ScoreCelebrationTier.perfect,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
