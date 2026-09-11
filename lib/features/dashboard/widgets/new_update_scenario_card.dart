import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/learning_providers.dart';
import '../../../app/new_update_scenario_provider.dart';
import '../dashboard_palette.dart';
import 'dashboard_compact_link_card.dart';

/// 홈 — 컴팩트 링크형 New Update 카드.
class NewUpdateScenarioCard extends ConsumerWidget {
  const NewUpdateScenarioCard({super.key});

  static const _slate = Color(0xFF0F172A);

  void _openScenario(BuildContext context, WidgetRef ref) {
    final snapshot = ref.read(newUpdateScenarioProvider);
    final scenario = snapshot.featured;
    if (scenario == null) return;

    selectLearningLanguage(ref, scenario.language);
    context.push('/scenarios/train/${scenario.id}', extra: scenario);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(newUpdateScenarioProvider);
    if (!snapshot.hasUpdates) return const SizedBox.shrink();

    final scenario = snapshot.featured!;
    final level = scenarioLevelLabel(scenario.level);
    final lineCount = scenario.lines.length;

    return DashboardCompactLinkCard(
      tintColors: [
        const Color(0xFFFAFAF9).withValues(alpha: 0.94),
        const Color(0xFFF5F5F4).withValues(alpha: 0.78),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DashboardSectionLabel(
                  icon: Icons.auto_awesome_rounded,
                  label: 'NEW UPDATE',
                  accent: DashboardPalette.sectionNewUpdate,
                ),
                const Spacer(),
                DashboardMetaChip(
                  label: scenarioLanguageShortTag(scenario.language),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                const DashboardMetaChip(
                  icon: Icons.theater_comedy_outlined,
                  label: '시나리오 학습',
                ),
                DashboardMetaChip(label: level),
                DashboardMetaChip(label: '$lineCount문장'),
                if (snapshot.additionalCount > 0)
                  DashboardMetaChip(
                    label: '외 ${snapshot.additionalCount}개',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scenario.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: _slate,
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: DashboardCompactLink(
                label: '시나리오 도전 ▶',
                onPressed: () => _openScenario(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
