import 'dart:ui';
import 'package:flutter/material.dart';
import '../../dashboard/dashboard_palette.dart';

class ScenarioGlassHeader extends StatelessWidget {
  final double progress;
  final String metaLabel;
  final Color accentColor;
  final VoidCallback onBack;
  final VoidCallback? onOptions;

  const ScenarioGlassHeader({
    super.key,
    required this.progress,
    required this.metaLabel,
    required this.accentColor,
    required this.onBack,
    this.onOptions,
  });

  static const double horizontalMargin = 20;
  static const double borderRadius = 24;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        horizontalMargin,
        16, // 💡 상단 여백을 넓혀 공중에 뜬 느낌을 극대화
        horizontalMargin,
        8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), // 💡 블러 강도를 살짝 높임
          child: Container(
            constraints: const BoxConstraints(minHeight: 60), // 💡 높이 밸런스 조정
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 14), // 💡 내부 여백 최적화
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4), // 💡 테두리를 더 선명하게
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                _HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: '뒤로',
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (metaLabel.trim().isNotEmpty) ...[
                        Text(
                          metaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5, // 💡 폰트 크기 업
                            fontWeight: FontWeight.w700, // 💡 가독성을 위해 굵기 업
                            color: DashboardPalette.textMuted,
                            letterSpacing: 0.3, // 💡 자간을 넓혀 고급스럽게
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _GlassProgressBar(
                        value: clamped,
                        accentColor: accentColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _HeaderIconButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: '옵션',
                  onPressed: onOptions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassProgressBar extends StatelessWidget {
  final double value;
  final Color accentColor;

  const _GlassProgressBar({
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10, // 💡 두께를 8에서 10으로 늘려 시각적 대칭 확보
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 💡 게이지 배경 트랙을 조금 더 차분하고 고급스러운 톤으로 변경
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.05),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      accentColor,
                      Color.lerp(accentColor, Colors.white, 0.35)!, // 💡 입체감 강화
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      color: DashboardPalette.navy.withValues(alpha: 0.75),
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}