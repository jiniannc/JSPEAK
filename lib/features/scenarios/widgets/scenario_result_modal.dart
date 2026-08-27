import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/scenario.dart';
import '../../../data/models/scenario_training_result.dart';
import '../../../shared/widgets/score_celebration_overlay.dart';
import '../../../shared/widgets/web_safe_backdrop_blur.dart';

class ScenarioResultModal extends StatefulWidget {
  final ScenarioTrainingResult result;
  final String scenarioTitle;
  final VoidCallback onRetry;
  final VoidCallback onExit;
  final Scenario? previousScenario;
  final Scenario? nextScenario;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const ScenarioResultModal({
    super.key,
    required this.result,
    required this.scenarioTitle,
    required this.onRetry,
    required this.onExit,
    this.previousScenario,
    this.nextScenario,
    this.onPrevious,
    this.onNext,
  });

  static Future<void> show({
    required BuildContext context,
    required ScenarioTrainingResult result,
    required String scenarioTitle,
    required VoidCallback onRetry,
    required VoidCallback onExit,
    Scenario? previousScenario,
    Scenario? nextScenario,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
  }) {
    var celebrationScheduled = false;
    final tier = ScoreCelebrationTier.fromPercent(result.score);

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        if (!celebrationScheduled && tier != ScoreCelebrationTier.none) {
          celebrationScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (sheetContext.mounted) {
              ScoreCelebrationOverlay.showOnRoot(sheetContext, tier);
            }
          });
        }
        final screenSize = MediaQuery.sizeOf(sheetContext);
        final sheetHeight = screenSize.height * 0.88;
        return SizedBox(
          height: screenSize.height,
          width: screenSize.width,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: sheetHeight,
              ),
              child: ScenarioResultModal(
                result: result,
                scenarioTitle: scenarioTitle,
                onRetry: () {
                  Navigator.of(sheetContext).pop();
                  onRetry();
                },
                onExit: () {
                  Navigator.of(sheetContext).pop();
                  onExit();
                },
                previousScenario: previousScenario,
                nextScenario: nextScenario,
                onPrevious: onPrevious == null
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        onPrevious();
                      },
                onNext: onNext == null
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        onNext();
                      },
              ),
            ),
          ),
        );
      },
    ).whenComplete(ScoreCelebrationOverlay.dismissRoot);
  }

  @override
  State<ScenarioResultModal> createState() => _ScenarioResultModalState();
}

class _ScenarioResultModalState extends State<ScenarioResultModal>
    with SingleTickerProviderStateMixin {
  static const _emerald = Color(0xFF10B981);
  static const _cyan = Color(0xFF06B6D4);
  static const _coral = Color(0xFFF43F5E);
  static const _slate = Color(0xFF0F172A);
  static const _subMuted = Color(0xFF64748B);

  late final AnimationController _chartController;

  ScenarioTrainingResult get result => widget.result;

  Color get _gradeColor => switch (result.grade) {
        ScenarioPerformanceGrade.s => const Color(0xFF9333EA),
        ScenarioPerformanceGrade.a => const Color(0xFF0D9488),
        ScenarioPerformanceGrade.b => const Color(0xFF0284C7),
        ScenarioPerformanceGrade.c => const Color(0xFFD97706),
        ScenarioPerformanceGrade.d => const Color(0xFF64748B),
      };

  double get _scoreRatio => result.score / 100;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (result.score >= 90) {
        HapticFeedback.heavyImpact();
      } else if (result.score >= 70) {
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: WebSafeBackdropBlur(
        sigmaX: 18,
        sigmaY: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: kIsWeb ? 0.97 : 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModalHeader(onClose: widget.onExit),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: Text(
                    widget.scenarioTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _slate.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _RankBadge(
                  medal: result.gradeMedal,
                  title: result.gradeTitle,
                  badgeColor: _gradeColor,
                ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 168,
                    height: 168,
                    child: AnimatedBuilder(
                      animation: _chartController,
                      builder: (context, _) {
                        final animatedValue = Curves.easeOutCubic.transform(
                          _chartController.value,
                        );
                        final displayScore =
                            (result.score * animatedValue).round();
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _DonutProgressPainter(
                                  knownRatio: _scoreRatio,
                                  animationValue: animatedValue,
                                  knownGradientColors: const [_emerald, _cyan],
                                  unknownColor: _coral.withValues(alpha: 0.55),
                                  trackColor: _slate.withValues(alpha: 0.06),
                                  strokeWidth: 14,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$displayScore',
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    color: _slate,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PERFORMANCE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: _slate.withValues(alpha: 0.40),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    result.coachingComment,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _subMuted,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _ScoreDimensionRow(
                    result: result,
                    animation: _chartController,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.previousScenario != null ||
                          widget.nextScenario != null) ...[
                        Text(
                          '다른 시나리오',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: _slate.withValues(alpha: 0.38),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ScenarioNavRow(
                          previous: widget.previousScenario,
                          next: widget.nextScenario,
                          onPrevious: widget.onPrevious,
                          onNext: widget.onNext,
                        ),
                        const SizedBox(height: 10),
                      ],
                      _LiquidGlassActionButton(
                        onPressed: widget.onRetry,
                        label: '다시 도전',
                      ),
                      TextButton(
                        onPressed: widget.onExit,
                        style: TextButton.styleFrom(
                          foregroundColor: _subMuted,
                          minimumSize: const Size.fromHeight(36),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          '목차로 돌아가기',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

class _ModalHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _ModalHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
      child: Row(
        children: [
          const Text(
            '✈ SCENARIO COMPLETE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Text(
              '✕',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A).withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final String medal;
  final String title;
  final Color badgeColor;

  const _RankBadge({
    required this.medal,
    required this.title,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(medal, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MiniRingMode { single, composite }

class _ScoreFactorSpec {
  final String title;
  final String guide;
  final _MiniRingMode mode;
  final double fillRatio;
  final List<(double ratio, List<Color> colors)> compositeSegments;
  final List<Color> fillGradient;
  final IconData icon;
  final Color? iconTint;

  const _ScoreFactorSpec({
    required this.title,
    required this.guide,
    required this.mode,
    this.fillRatio = 0,
    this.compositeSegments = const [],
    this.fillGradient = const [Color(0xFF10B981), Color(0xFF06B6D4)],
    required this.icon,
    this.iconTint,
  });
}

class _ScoreDimensionRow extends StatelessWidget {
  final ScenarioTrainingResult result;
  final Animation<double> animation;

  static const _emerald = Color(0xFF10B981);
  static const _teal = Color(0xFF14B8A6);
  static const _violet = Color(0xFF8B5CF6);
  static const _indigo = Color(0xFF6366F1);
  static const _amber = Color(0xFFF59E0B);
  static const _orange = Color(0xFFF97316);
  static const _sky = Color(0xFF0EA5E9);
  static const _blue = Color(0xFF3B82F6);
  static const _lime = Color(0xFF84CC16);
  static const _green = Color(0xFF22C55E);
  static const _track = Color(0xFFE2E8F0);
  static const _divider = Color(0x140F172A);

  const _ScoreDimensionRow({
    required this.result,
    required this.animation,
  });

  List<_ScoreFactorSpec> _buildSpecs() {
    return [
      _ScoreFactorSpec(
        title: '응대 방식',
        guide: '키보드보다 녹음을 하면\n점수가 더 높아져요',
        mode: _MiniRingMode.composite,
        icon: Icons.mic_rounded,
        iconTint: _teal,
        compositeSegments: [
          (result.voicePassRatio, const [_emerald, _teal]),
          (result.keyboardResolutionRatio, const [_violet, _indigo]),
        ],
      ),
      _ScoreFactorSpec(
        title: '시도 횟수',
        guide: '시도 횟수가 적을수록\n점수가 높아져요',
        mode: _MiniRingMode.single,
        fillRatio: result.efficiencyRatio,
        fillGradient: const [_orange, _amber],
        icon: Icons.bolt_rounded,
        iconTint: _orange,
      ),
      _ScoreFactorSpec(
        title: '스피킹',
        guide: '녹음을 시도하면\n보너스 점수가 들어가요',
        mode: _MiniRingMode.single,
        fillRatio: result.speakingParticipationRatio,
        fillGradient: const [_blue, _sky],
        icon: Icons.graphic_eq_rounded,
        iconTint: _blue,
      ),
      _ScoreFactorSpec(
        title: '힌트',
        guide: '힌트를 사용하지 않을수록\n점수가 높아져요',
        mode: _MiniRingMode.single,
        fillRatio: result.hintFreeRatio,
        fillGradient: const [_lime, _green],
        icon: Icons.lightbulb_outline_rounded,
        iconTint: _lime,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final specs = _buildSpecs();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < specs.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _divider,
                ),
              ),
            Expanded(
              child: _ScoreFactorTile(
                spec: specs[i],
                animation: animation,
                trackColor: _track,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreFactorTile extends StatelessWidget {
  final _ScoreFactorSpec spec;
  final Animation<double> animation;
  final Color trackColor;

  const _ScoreFactorTile({
    required this.spec,
    required this.animation,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    const slate = Color(0xFF0F172A);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: 0.45 + 0.55 * t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(64, 64),
                      painter: spec.mode == _MiniRingMode.composite
                          ? _CompositeMiniRingPainter(
                              segments: spec.compositeSegments,
                              trackColor: trackColor,
                              animationValue: t,
                              strokeWidth: 6,
                            )
                          : _SingleMiniRingPainter(
                              fillRatio: spec.fillRatio,
                              fillGradient: spec.fillGradient,
                              trackColor: trackColor,
                              animationValue: t,
                              strokeWidth: 6,
                            ),
                    ),
                    Icon(
                      spec.icon,
                      size: 20,
                      color: (spec.iconTint ?? slate).withValues(alpha: 0.42),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                spec.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: slate.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                spec.guide,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: slate.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 단일 fill — 집계 비율(0~1)만 표시.
class _SingleMiniRingPainter extends CustomPainter {
  final double fillRatio;
  final List<Color> fillGradient;
  final Color trackColor;
  final double animationValue;
  final double strokeWidth;

  const _SingleMiniRingPainter({
    required this.fillRatio,
    required this.fillGradient,
    required this.trackColor,
    required this.animationValue,
    this.strokeWidth = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;
    final ratio = fillRatio.clamp(0.0, 1.0);
    final fillSweep = fullSweep * ratio * animationValue;

    canvas.drawArc(
      rect,
      0,
      fullSweep,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (fillSweep <= 0.001) return;

    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (kIsWeb) {
      fillPaint.color = fillGradient.last;
    } else {
      final gradient = SweepGradient(
        colors: fillGradient,
        startAngle: startAngle,
        endAngle: startAngle + math.max(fillSweep, 0.001),
      );
      fillPaint.shader = gradient.createShader(rect);
    }

    canvas.drawArc(rect, startAngle, fillSweep, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SingleMiniRingPainter oldDelegate) {
    return oldDelegate.fillRatio != fillRatio ||
        oldDelegate.animationValue != animationValue;
  }
}

/// 녹음 / 키보드 비율을 한 링에 순서대로 표시. 정답 확인 턴은 빈 구간.
class _CompositeMiniRingPainter extends CustomPainter {
  final List<(double ratio, List<Color> colors)> segments;
  final Color trackColor;
  final double animationValue;
  final double strokeWidth;

  const _CompositeMiniRingPainter({
    required this.segments,
    required this.trackColor,
    required this.animationValue,
    this.strokeWidth = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    canvas.drawArc(
      rect,
      0,
      fullSweep,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    var cursor = startAngle;
    for (final (ratio, colors) in segments) {
      final sweep = fullSweep * ratio.clamp(0.0, 1.0) * animationValue;
      if (sweep <= 0.001) continue;

      final color = colors.length > 1 ? colors.last : colors.first;
      canvas.drawArc(
        rect,
        cursor,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
      cursor += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CompositeMiniRingPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.animationValue != animationValue;
  }
}

class _ScenarioNavRow extends StatelessWidget {
  final Scenario? previous;
  final Scenario? next;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _ScenarioNavRow({
    required this.previous,
    required this.next,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrevious = previous != null && onPrevious != null;
    final hasNext = next != null && onNext != null;

    if (!hasPrevious && !hasNext) return const SizedBox.shrink();

    if (hasPrevious && hasNext) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _ScenarioNavCard(
                  scenario: previous!,
                  direction: _ScenarioNavDirection.previous,
                  onTap: onPrevious!,
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: const Color(0xFF0F172A).withValues(alpha: 0.07),
              ),
              Expanded(
                child: _ScenarioNavCard(
                  scenario: next!,
                  direction: _ScenarioNavDirection.next,
                  onTap: onNext!,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final scenario = hasPrevious ? previous! : next!;
    final direction = hasPrevious
        ? _ScenarioNavDirection.previous
        : _ScenarioNavDirection.next;
    final onTap = hasPrevious ? onPrevious! : onNext!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (!hasPrevious) const Expanded(child: SizedBox.shrink()),
          Expanded(
            child: _ScenarioNavCard(
              scenario: scenario,
              direction: direction,
              onTap: onTap,
            ),
          ),
          if (!hasNext) const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

enum _ScenarioNavDirection { previous, next }

class _ScenarioNavCard extends StatelessWidget {
  final Scenario scenario;
  final _ScenarioNavDirection direction;
  final VoidCallback onTap;

  const _ScenarioNavCard({
    required this.scenario,
    required this.direction,
    required this.onTap,
  });

  bool get _isPrevious => direction == _ScenarioNavDirection.previous;

  String get _directionLabel => _isPrevious ? '이전' : '다음';

  String get _chapterLabel {
    final name = scenario.chapterName.trim();
    if (name.isEmpty) return 'Chapter ${scenario.chapterNo}';
    return 'Ch.${scenario.chapterNo} $name';
  }

  @override
  Widget build(BuildContext context) {
    const slate = Color(0xFF0F172A);
    const accent = Color(0xFF0D9488);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Row(
            children: [
              if (_isPrevious)
                Icon(
                  Icons.chevron_left_rounded,
                  size: 17,
                  color: slate.withValues(alpha: 0.35),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: _isPrevious
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _directionLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scenario.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          _isPrevious ? TextAlign.start : TextAlign.end,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: slate.withValues(alpha: 0.82),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _chapterLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          _isPrevious ? TextAlign.start : TextAlign.end,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: slate.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isPrevious)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: slate.withValues(alpha: 0.35),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _LiquidGlassActionButton({
    required this.onPressed,
    required this.label,
  });

  static const _gradientColors = [Color(0xF10D9488), Color(0xF10891B2)];

  static const _textShadows = [
    Shadow(
      color: Color(0x40000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    Shadow(
      color: Color(0x26000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: WebSafeBackdropBlur(
              sigmaX: 12,
              sigmaY: 12,
              child: Ink(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: _textShadows,
                    ),
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

class _DonutProgressPainter extends CustomPainter {
  final double knownRatio;
  final double animationValue;
  final List<Color> knownGradientColors;
  final Color unknownColor;
  final Color trackColor;
  final double strokeWidth;

  const _DonutProgressPainter({
    required this.knownRatio,
    required this.animationValue,
    required this.knownGradientColors,
    required this.unknownColor,
    required this.trackColor,
    this.strokeWidth = 11,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = strokeWidth;
    final radius = math.min(size.width, size.height) / 2 - stroke - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final knownSweep = 2 * math.pi * knownRatio * animationValue;
    final unknownRatio = (1 - knownRatio).clamp(0.0, 1.0);
    final unknownSweep = 2 * math.pi * unknownRatio * animationValue;

    if (knownSweep > 0 && !kIsWeb) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 8
        ..strokeCap = StrokeCap.round
        ..color = knownGradientColors.last.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(rect, startAngle, knownSweep, false, glowPaint);
    }
    if (unknownSweep > 0 && !kIsWeb) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 8
        ..strokeCap = StrokeCap.round
        ..color = unknownColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(
        rect,
        startAngle + knownSweep,
        unknownSweep,
        false,
        glowPaint,
      );
    }

    if (knownSweep > 0) {
      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      if (kIsWeb) {
        fillPaint.color = knownGradientColors.last;
      } else {
        final gradient = SweepGradient(
          colors: knownGradientColors,
          startAngle: startAngle,
          endAngle: startAngle + math.max(knownSweep, 0.001),
        );
        fillPaint.shader = gradient.createShader(rect);
      }
      canvas.drawArc(rect, startAngle, knownSweep, false, fillPaint);
    }

    if (unknownSweep > 0) {
      canvas.drawArc(
        rect,
        startAngle + knownSweep,
        unknownSweep,
        false,
        Paint()
          ..color = unknownColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutProgressPainter oldDelegate) {
    return oldDelegate.knownRatio != knownRatio ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
