import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/scenario_providers.dart';
import '../../../data/models/scenario.dart';
import '../../dashboard/dashboard_palette.dart';
import '../../scenarios/widgets/scenario_bubble_avatar.dart';
import '../../shell/floating_island_nav_bar.dart';
import 'hub_mode_picker_shared.dart';
import 'mode_guide_cards.dart';

/// 시나리오 롤플레잉 진입 — 문장 스피킹과 동일한 오버레이 피커.
void openScenarioPicker(
  BuildContext context, {
  required WidgetRef ref,
  required List<Scenario> scenarios,
  required bool Function(String scenarioId) isCompleted,
  GlobalKey? popupAnchorKey,
}) {
  if (scenarios.isEmpty) return;

  final resolved = popupAnchorKey == null
      ? null
      : popupAnchorFor(context, anchorKey: popupAnchorKey);
  if (resolved == null) {
    if (!context.mounted) return;
    context.push(
      '/scenarios/train/${Uri.encodeComponent(scenarios.first.id)}',
      extra: scenarios.first,
    );
    return;
  }

  final parent = context;
  final language =
      scenarios.isEmpty ? 'English' : scenarios.first.language;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => Consumer(
      builder: (context, ref, _) {
        final stats = ref.watch(scenarioProgressProvider).stats;
        return _ScenarioPickerOverlay(
          anchor: resolved.anchor,
          anchorSize: resolved.size,
          scenarios: scenarios,
          isCompleted: (id) => stats.isCompleted(language, id),
          lastPerformance: (id) => stats.lastPerformance(language, id),
          onDismiss: () {
            if (entry.mounted) entry.remove();
          },
          onSelect: (scenario) {
            if (entry.mounted) entry.remove();
            if (!parent.mounted) return;
            parent.push(
              '/scenarios/train/${Uri.encodeComponent(scenario.id)}',
              extra: scenario,
            );
          },
        );
      },
    ),
  );
  resolved.overlay.insert(entry);
}

class _ScenarioPickerOverlay extends StatefulWidget {
  const _ScenarioPickerOverlay({
    required this.anchor,
    required this.anchorSize,
    required this.scenarios,
    required this.isCompleted,
    required this.lastPerformance,
    required this.onDismiss,
    required this.onSelect,
  });

  final Offset anchor;
  final Size anchorSize;
  final List<Scenario> scenarios;
  final bool Function(String scenarioId) isCompleted;
  final int? Function(String scenarioId) lastPerformance;
  final VoidCallback onDismiss;
  final ValueChanged<Scenario> onSelect;

  @override
  State<_ScenarioPickerOverlay> createState() => _ScenarioPickerOverlayState();
}

class _ScenarioPickerOverlayState extends State<_ScenarioPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _dimOpacity;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _scale;

  bool? _opensBelow;
  Animation<double>? _slideY;
  Animation<double>? _tiltX;
  Animation<double>? _liftShadow;

  static const _preferredPopupWidth = 292.0;
  static const _screenMargin = 14.0;
  static const _anchorGap = 8.0;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 320),
    );

    _dimOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0, 0.85, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    _panelOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.15, 1, curve: Curves.easeInCubic),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.08).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 45,
      ),
    ]).animate(_entry);

    _entry.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ScenarioBubbleAvatar.precacheScenarios(context, widget.scenarios),
      );
    });
  }

  void _ensureDirectionalMotion(bool opensBelow) {
    if (_opensBelow == opensBelow && _slideY != null) return;
    _opensBelow = opensBelow;

    final slideBegin = opensBelow ? -28.0 : 28.0;
    final tiltBegin = opensBelow ? 0.18 : -0.18;
    final motion = CurvedAnimation(
      parent: _entry,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    _slideY = Tween<double>(begin: slideBegin, end: 0).animate(motion);
    _tiltX = Tween<double>(begin: tiltBegin, end: 0).animate(motion);
    _liftShadow = Tween<double>(begin: 0.28, end: 1).animate(
      CurvedAnimation(
        parent: _entry,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_entry.status == AnimationStatus.reverse ||
        _entry.status == AnimationStatus.dismissed) {
      return;
    }
    await _entry.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final pad = media.padding;
    final popupWidth = math.min(
      _preferredPopupWidth,
      math.max(1.0, size.width - _screenMargin * 2),
    );
    final estimatedHeight = math.min(
      widget.scenarios.length * 46.0 + 62,
      math.max(120.0, size.height * 0.52),
    );
    final bottomObstruction =
        pad.bottom + FloatingIslandNavBar.reservedHeight(context);
    final safeTop = pad.top + _screenMargin;
    final safeBottom = math.max(
      safeTop + 120,
      size.height - bottomObstruction - _screenMargin,
    );
    final anchorTop = widget.anchor.dy;
    final anchorBottom = widget.anchor.dy + widget.anchorSize.height;
    final spaceAbove = math.max(0.0, anchorTop - safeTop - _anchorGap);
    final spaceBelow = math.max(0.0, safeBottom - anchorBottom - _anchorGap);
    final showBelow = spaceBelow >= estimatedHeight;
    final availableHeight = math.max(
      120.0,
      math.min(
        estimatedHeight,
        math.min(
          showBelow ? spaceBelow : spaceAbove,
          math.max(120.0, safeBottom - safeTop),
        ),
      ),
    );

    var left = widget.anchor.dx + widget.anchorSize.width / 2 - popupWidth / 2;
    left = left.clamp(
      _screenMargin,
      math.max(_screenMargin, size.width - popupWidth - _screenMargin),
    );

    final popupTop = showBelow
        ? (anchorBottom + _anchorGap).clamp(safeTop, safeBottom - 80)
        : (anchorTop - _anchorGap - availableHeight).clamp(
            safeTop,
            anchorTop - _anchorGap,
          );

    _ensureDirectionalMotion(showBelow);
    final panelAlignment =
        showBelow ? Alignment.topCenter : Alignment.bottomCenter;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: FadeTransition(
              opacity: _dimOpacity,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
        ),
        Positioned(
          left: left,
          width: popupWidth,
          top: popupTop,
          child: AnimatedBuilder(
            animation: _entry,
            builder: (context, child) {
              final lift = _liftShadow!.value;
              return Transform(
                alignment: panelAlignment,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.00115)
                  ..translate(0.0, _slideY!.value)
                  ..rotateX(_tiltX!.value)
                  ..scale(_scale.value, _scale.value, 1.0),
                child: Opacity(
                  opacity: _panelOpacity.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.06 + 0.14 * lift,
                          ),
                          blurRadius: 10 + 26 * lift,
                          spreadRadius: -1,
                          offset: Offset(0, 5 + 14 * lift),
                        ),
                        BoxShadow(
                          color: DashboardPalette.teal.withValues(
                            alpha: 0.04 + 0.08 * lift,
                          ),
                          blurRadius: 18 + 12 * lift,
                          spreadRadius: -4,
                          offset: Offset(0, 8 + 6 * lift),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight),
                child: SingleChildScrollView(
                  child: _ScenarioPickerPanel(
                    scenarios: widget.scenarios,
                    isCompleted: widget.isCompleted,
                    lastPerformance: widget.lastPerformance,
                    onSelect: widget.onSelect,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioPickerPanel extends StatelessWidget {
  const _ScenarioPickerPanel({
    required this.scenarios,
    required this.isCompleted,
    required this.lastPerformance,
    required this.onSelect,
  });

  final List<Scenario> scenarios;
  final bool Function(String scenarioId) isCompleted;
  final int? Function(String scenarioId) lastPerformance;
  final ValueChanged<Scenario> onSelect;

  static const _dividerColor = Color(0x120F172A);
  static const _dividerInset = 12.0;

  @override
  Widget build(BuildContext context) {
    final panelBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HubModePickerHeader(
          icon: Icons.forum_rounded,
          title: '시나리오 선택',
          accent: DashboardPalette.teal,
          guideBuilder: (dismiss) => ScenarioModeGuideCard(onDismiss: dismiss),
        ),
        for (var i = 0; i < scenarios.length; i++) ...[
          _ScenarioPickerRow(
            index: i + 1,
            scenario: scenarios[i],
            completed: isCompleted(scenarios[i].id),
            lastScore: lastPerformance(scenarios[i].id),
            onTap: () => onSelect(scenarios[i]),
          ),
          if (i < scenarios.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: _dividerInset),
              child: Divider(height: 1, thickness: 1, color: _dividerColor),
            ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: panelBody,
          ),
        ),
      ),
    );
  }
}

class _ScenarioPickerRow extends StatelessWidget {
  const _ScenarioPickerRow({
    required this.index,
    required this.scenario,
    required this.completed,
    required this.lastScore,
    required this.onTap,
  });

  final int index;
  final Scenario scenario;
  final bool completed;
  final int? lastScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$index. ${scenario.title.isNotEmpty ? scenario.title : scenario.flightStage}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: DashboardPalette.navy,
                ),
              ),
            ),
            if (scenario.isNewContent && !completed)
              const Padding(
                padding: EdgeInsets.only(left: 6, right: 4),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF5252),
                  ),
                ),
              ),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: DashboardPalette.teal.withValues(alpha: 0.88),
                ),
              ),
            if (!completed && lastScore == null)
              const HubPickerStartCue(accent: DashboardPalette.teal)
            else if (lastScore != null)
              _ScenarioLastScoreRing(score: lastScore!),
          ],
        ),
      ),
    );
  }
}

class _ScenarioLastScoreRing extends StatelessWidget {
  const _ScenarioLastScoreRing({required this.score});

  const _ScenarioLastScoreRing.empty() : score = null;

  final int? score;

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    const stroke = 3.5;
    const track = Color(0xFFE2E8F0);

    if (score == null) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MiniScoreRingPainter(
            ratio: 0,
            fillColors: const [track, track],
            trackColor: track,
            strokeWidth: stroke,
          ),
        ),
      );
    }

    final ratio = (score! / 100).clamp(0.0, 1.0);
    final fillColors = switch (score!) {
      >= 85 => const [Color(0xFF10B981), Color(0xFF06B6D4)],
      >= 55 => const [Color(0xFF0284C7), Color(0xFF38BDF8)],
      _ => const [Color(0xFFF43F5E), Color(0xFFFB7185)],
    };

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _MiniScoreRingPainter(
              ratio: ratio,
              fillColors: fillColors,
              trackColor: track,
              strokeWidth: stroke,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              height: 1,
              color: DashboardPalette.navy.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniScoreRingPainter extends CustomPainter {
  const _MiniScoreRingPainter({
    required this.ratio,
    required this.fillColors,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double ratio;
  final List<Color> fillColors;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;
    final fillSweep = fullSweep * ratio.clamp(0.0, 1.0);

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

    final gradient = SweepGradient(
      colors: fillColors,
      startAngle: startAngle,
      endAngle: startAngle + math.max(fillSweep, 0.001),
    );

    canvas.drawArc(
      rect,
      startAngle,
      fillSweep,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniScoreRingPainter oldDelegate) {
    return oldDelegate.ratio != ratio || oldDelegate.fillColors != fillColors;
  }
}
