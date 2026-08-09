import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/labels.dart';
import '../../../core/theme/language_palette.dart';
import '../../../data/models/scenario.dart';
import '../../../features/dashboard/dashboard_palette.dart';

const _chevronGray = Color(0xFFB8BFC9);

/// flight_stage · level 미니 태그.
class ScenarioTagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const ScenarioTagChip({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10.5 : 11,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.82),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

Color levelColor(String level) {
  final normalized = level.trim();
  if (normalized.contains('초급') || normalized.toLowerCase() == 'beginner') {
    return const Color(0xFF7EB892);
  }
  if (normalized.contains('중급') || normalized.toLowerCase() == 'intermediate') {
    return const Color(0xFFE0A86B);
  }
  if (normalized.contains('고급') || normalized.toLowerCase() == 'advanced') {
    return const Color(0xFFD98A8A);
  }
  return const Color(0xFF6BAFB2);
}

/// 시나리오 목록 카드 — 컴팩트 1줄 태그 + 슬림 패딩.
class ScenarioListCard extends StatelessWidget {
  final Scenario scenario;
  final bool isCompleted;
  final VoidCallback onTap;

  const ScenarioListCard({
    super.key,
    required this.scenario,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.languagePalette ?? LanguagePalette.english;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: palette
                  .glassCardDecoration(
                    radius: 14,
                    fillAlpha: 0.58,
                    borderAlpha: 0.4,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  )
                  .copyWith(
                    border: Border.all(
                      color: isCompleted
                          ? palette.primary.withValues(alpha: 0.2)
                          : palette.glassBorder(alpha: 0.4),
                    ),
                  ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          scenario.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DashboardPalette.navy,
                            letterSpacing: -0.2,
                            height: 1.25,
                          ),
                        ),
                        if (scenario.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            scenario.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: DashboardPalette.textMuted,
                              height: 1.3,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: palette.primary.withValues(alpha: 0.75),
                            ),
                          ),
                        if (scenario.level.isNotEmpty)
                          ScenarioTagChip(
                            label: scenario.level,
                            color: levelColor(scenario.level),
                            compact: true,
                          ),
                        if (scenario.level.isNotEmpty) const SizedBox(width: 4),
                        ScenarioTagChip(
                          label: '${scenario.lines.length}턴',
                          color: const Color(0xFF8A94A6),
                          compact: true,
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: _chevronGray,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 언어별 진도 — 슬림 프로그레스 바.
class ScenarioProgressHeader extends StatelessWidget {
  final String languageLabel;
  final double percent;
  final int completed;
  final int total;
  final Color accentColor;
  final EdgeInsetsGeometry margin;

  const ScenarioProgressHeader({
    super.key,
    required this.languageLabel,
    required this.percent,
    required this.completed,
    required this.total,
    required this.accentColor,
    this.margin = const EdgeInsets.fromLTRB(20, 4, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    final rounded = percent.round();
    final palette = context.languagePalette ?? LanguagePalette.english;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: palette.glassCardDecoration(
              radius: 12,
              fillAlpha: 0.52,
              borderAlpha: 0.42,
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '$rounded%',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$languageLabel 훈련 완료',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DashboardPalette.navy,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    Text(
                      '$completed/$total',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: DashboardPalette.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : percent / 100,
                    minHeight: 4,
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    color: accentColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String scenarioLanguageShortLabel(String language) =>
    languageLabel(language);
