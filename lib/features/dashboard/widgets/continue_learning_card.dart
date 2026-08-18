import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/continue_learning_provider.dart';
import '../../../app/learning_hub_language_provider.dart';
import '../../../app/scenario_providers.dart';
import '../../../app/sentence_progress_providers.dart';
import '../../../app/swipe_progress_providers.dart';
import '../../../core/constants/labels.dart';
import '../../word_swipe/word_swipe_training_screen.dart';
import 'dashboard_compact_link_card.dart';

/// 홈 — 컴팩트 링크형 Continue Learning 카드.
class ContinueLearningCard extends ConsumerWidget {
  const ContinueLearningCard({super.key});

  static const _slate = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(continueLearningProvider);

    return DashboardCompactLinkCard(
      tintColors: [
        const Color(0xFFF8FAFC).withValues(alpha: 0.94),
        const Color(0xFFF1F5F9).withValues(alpha: 0.78),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DashboardSectionLabel(
                  icon: Icons.bolt_rounded,
                  label: 'CONTINUE LEARNING',
                ),
                const Spacer(),
                if (target.hasProgress)
                  DashboardMetaChip(
                    label:
                        '${target.completed}/${target.total} · ${target.progressPercent}%',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DashboardMetaChip(
                  icon: target.icon,
                  label: target.modeLabel,
                ),
                if (target.kind != ContinueLearningKind.learningHub)
                  DashboardMetaChip(
                    label: languageLabel(target.language),
                  ),
                if (target.reviewOnly)
                  const DashboardMetaChip(label: '복습 모드'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              target.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _slate,
                height: 1.25,
              ),
            ),
            if (target.kind == ContinueLearningKind.learningHub) ...[
              const SizedBox(height: 2),
              Text(
                target.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _slate.withValues(alpha: 0.45),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (target.hasProgress)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: _slate.withValues(alpha: 0.06),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: target.progressRatio.clamp(0.0, 1.0),
                              child: ColoredBox(
                                color: _slate.withValues(alpha: 0.28),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                DashboardCompactLink(
                  label: target.kind == ContinueLearningKind.learningHub
                      ? '학습 시작하기 ▶'
                      : '이어서 하기 ▶',
                  onPressed: () => _navigate(context, ref, target),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(
    BuildContext context,
    WidgetRef ref,
    ContinueLearningTarget target,
  ) {
    switch (target.kind) {
      case ContinueLearningKind.wordSwipe:
        ref.read(swipeLanguageProvider.notifier).set(target.language);
        ref.read(learningHubLanguageProvider.notifier).set(target.language);
        context.push(
          '/scenarios/swipe/play',
          extra: WordSwipeArgs(
            language: target.language,
            category: target.category ?? '',
            reviewOnly: target.reviewOnly,
          ),
        );
      case ContinueLearningKind.basicSentence:
        ref.read(basicSentenceLanguageProvider.notifier).set(target.language);
        ref.read(learningHubLanguageProvider.notifier).set(target.language);
        context.push(
          '/scenarios/sentences/play'
          '?lang=${Uri.encodeComponent(target.language)}'
          '&category=${Uri.encodeComponent(target.category ?? '')}',
        );
      case ContinueLearningKind.scenario:
        ref.read(scenarioLanguageProvider.notifier).set(target.language);
        ref.read(learningHubLanguageProvider.notifier).set(target.language);
        final scenario = target.scenario;
        if (scenario != null) {
          context.push('/scenarios/train/${scenario.id}', extra: scenario);
        } else {
          context.go('/scenarios');
        }
      case ContinueLearningKind.learningHub:
        context.go('/scenarios');
    }
  }
}
