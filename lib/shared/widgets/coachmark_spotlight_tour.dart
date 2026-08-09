import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 코치마크 스팟라이트 포커스 형태.
enum CoachmarkTourFocusShape { roundedRect, circle }

/// 코치마크 투어 단계 정의.
class CoachmarkTourStep {
  final GlobalKey targetKey;
  final String title;
  final String body;
  final List<String> emphasisWords;
  final CoachmarkTourFocusShape shape;
  final double borderRadius;
  final EdgeInsets padding;
  final bool preferTooltipBelow;

  const CoachmarkTourStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.emphasisWords = const [],
    this.shape = CoachmarkTourFocusShape.roundedRect,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.all(6),
    this.preferTooltipBelow = false,
  });
}

/// 글래스 툴팁 + Path 기반 스팟라이트 코치마크 엔진.
class CoachmarkSpotlightTour {
  static const transitionDuration = Duration(milliseconds: 300);
  static const exitFadeDuration = Duration(milliseconds: 320);
  static const transitionCurve = Curves.easeInOutCubic;
  static const exitFadeCurve = Curves.easeOutCubic;
  static const cyanTint = Color(0xFF0891B2);
  static const spotlightMargin = 5.0;

  static OverlayEntry? _activeEntry;

  static bool get isShowing => _activeEntry != null;

  static void dismiss() {
    _activeEntry?.remove();
    _activeEntry = null;
  }

  static Future<void> show({
    required BuildContext context,
    required List<CoachmarkTourStep> steps,
    required VoidCallback onComplete,
    required VoidCallback onSkip,
  }) async {
    dismiss();
    if (steps.isEmpty) return;
    if (!context.mounted) return;

    // LayoutBuilder/AnimatedBuilder 레이아웃 중 overlay.insert 시 크래시 방지.
    await SchedulerBinding.instance.endOfFrame;
    if (!context.mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _CoachmarkSpotlightTourOverlay(
        steps: steps,
        onComplete: onComplete,
        onSkip: onSkip,
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _CoachmarkSpotlightTourOverlay extends StatefulWidget {
  final List<CoachmarkTourStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const _CoachmarkSpotlightTourOverlay({
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<_CoachmarkSpotlightTourOverlay> createState() =>
      _CoachmarkSpotlightTourOverlayState();
}

class _CoachmarkSpotlightTourOverlayState
    extends State<_CoachmarkSpotlightTourOverlay>
    with TickerProviderStateMixin {
  static const _maxMeasureRetries = 10;
  static const _measureRetryDelay = Duration(milliseconds: 80);

  late final AnimationController _transitionController;
  late final AnimationController _fadeOutController;

  int _stepIndex = 0;
  Rect? _fromRect;
  Rect? _toRect;
  Offset _tooltipOffset = Offset.zero;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: CoachmarkSpotlightTour.transitionDuration,
    )..addListener(() => setState(() {}));
    _fadeOutController = AnimationController(
      vsync: this,
      duration: CoachmarkSpotlightTour.exitFadeDuration,
      value: 1,
    )..addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureStep(animate: false));
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  Future<void> _exitAndThen(VoidCallback action) async {
    if (_isExiting) return;
    _isExiting = true;
    await _fadeOutController.animateTo(
      0,
      duration: CoachmarkSpotlightTour.exitFadeDuration,
      curve: CoachmarkSpotlightTour.exitFadeCurve,
    );
    if (!mounted) return;
    CoachmarkSpotlightTour.dismiss();
    action();
  }

  Rect? _rectForStep(int index) {
    if (index < 0 || index >= widget.steps.length) return null;
    final step = widget.steps[index];
    final ctx = step.targetKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    const margin = CoachmarkSpotlightTour.spotlightMargin;
    return Rect.fromLTRB(
      rect.left - step.padding.left - margin,
      rect.top - step.padding.top - margin,
      rect.right + step.padding.right + margin,
      rect.bottom + step.padding.bottom + margin,
    );
  }

  Future<void> _measureStep({
    required bool animate,
    int retryCount = 0,
  }) async {
    final next = _rectForStep(_stepIndex);
    if (next == null) {
      if (retryCount < _maxMeasureRetries) {
        await Future<void>.delayed(_measureRetryDelay);
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _measureStep(animate: animate, retryCount: retryCount + 1);
        });
        return;
      }

      if (_stepIndex < widget.steps.length - 1) {
        setState(() => _stepIndex++);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureStep(animate: animate),
        );
      }
      return;
    }

    if (animate && _toRect != null) {
      _fromRect = _transitionController.isAnimating
          ? Rect.lerp(_fromRect, _toRect, _transitionController.value)
          : _toRect;
    } else {
      _fromRect = next;
    }

    _toRect = next;
    _tooltipOffset = _tooltipPositionFor(next, _currentStep);

    if (animate) {
      _transitionController.forward(from: 0);
    } else {
      _transitionController.value = 1;
    }
    setState(() {});
  }

  Rect get _animatedHighlight {
    if (_fromRect == null || _toRect == null) {
      return _toRect ?? Rect.zero;
    }
    final t = CoachmarkSpotlightTour.transitionCurve
        .transform(_transitionController.value);
    return Rect.lerp(_fromRect, _toRect, t) ?? _toRect!;
  }

  CoachmarkTourStep get _currentStep => widget.steps[_stepIndex];

  Offset _tooltipPositionFor(Rect target, CoachmarkTourStep step) {
    const tooltipWidth = 300.0;
    const tooltipHeight = 148.0;
    const gap = 14.0;
    const hPad = 16.0;

    if (target.isEmpty) {
      return Offset(hPad, 88);
    }

    final screen = MediaQuery.sizeOf(context);
    final centerX = target.center.dx - tooltipWidth / 2;
    final left = centerX.clamp(hPad, screen.width - tooltipWidth - hPad);

    final spaceBelow = screen.height - target.bottom;
    final spaceAbove = target.top;

    double top;
    if (step.preferTooltipBelow) {
      top = target.bottom + gap;
    } else if (spaceBelow >= tooltipHeight + gap || spaceBelow >= spaceAbove) {
      top = target.bottom + gap;
    } else {
      top = target.top - tooltipHeight - gap;
    }
    top = top.clamp(12.0, screen.height - tooltipHeight - 12.0);

    return Offset(left, top);
  }

  void _goNext() {
    if (_isExiting) return;
    if (_stepIndex >= widget.steps.length - 1) {
      _exitAndThen(widget.onComplete);
      return;
    }
    setState(() => _stepIndex++);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureStep(animate: true));
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _animatedHighlight;
    final step = _currentStep;
    final total = widget.steps.length;
    final t = CoachmarkSpotlightTour.transitionCurve
        .transform(_transitionController.value);
    final tooltipTopLeft = Offset.lerp(
      _tooltipOffset,
      _tooltipPositionFor(highlight, step),
      t,
    )!;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _isExiting ? null : _goNext,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightDimPainter(
                  highlightRect: highlight,
                  borderRadius: step.borderRadius,
                  useCircle: step.shape == CoachmarkTourFocusShape.circle,
                  overlayOpacity: _fadeOutController.value,
                ),
              ),
            ),
            Positioned(
              left: tooltipTopLeft.dx,
              top: tooltipTopLeft.dy,
              width: 300,
              child: Opacity(
                opacity: _fadeOutController.value,
                child: _GlassTourTooltip(
                  title: step.title,
                  body: step.body,
                  emphasisWords: step.emphasisWords,
                  stepIndex: _stepIndex,
                  totalSteps: total,
                  onSkip: _isExiting
                      ? () {}
                      : () => _exitAndThen(widget.onSkip),
                ),
              ),
            ),
            Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: _fadeOutController.value,
                child: const _TourTapHintChip(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightDimPainter extends CustomPainter {
  final Rect highlightRect;
  final double borderRadius;
  final bool useCircle;
  final double overlayOpacity;

  const _SpotlightDimPainter({
    required this.highlightRect,
    required this.borderRadius,
    required this.useCircle,
    this.overlayOpacity = 1,
  });

  double _circleRadius(Rect rect) {
    return (rect.width > rect.height ? rect.width : rect.height) / 2;
  }

  RRect _focusRRect(Rect rect) {
    return RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (overlayOpacity <= 0) return;

    final screen = Rect.fromLTWH(0, 0, size.width, size.height);
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65 * overlayOpacity);

    if (highlightRect.isEmpty) {
      canvas.drawRect(screen, dimPaint);
      return;
    }

    // Web CanvasKit에서 PathOperation.difference는 구멍이 안 뚫히는 경우가 있어
    // evenOdd로 외곽 딤 + 내부 펀치홀을 한 번에 그린다.
    final spotlightPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(screen);

    if (useCircle) {
      spotlightPath.addOval(
        Rect.fromCircle(
          center: highlightRect.center,
          radius: _circleRadius(highlightRect),
        ),
      );
    } else {
      spotlightPath.addRRect(_focusRRect(highlightRect));
    }

    canvas.drawPath(spotlightPath, dimPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightDimPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.useCircle != useCircle ||
        oldDelegate.overlayOpacity != overlayOpacity;
  }
}

/// Web CanvasKit에서 BackdropFilter + saveLayer 조합 크래시를 피하기 위한 글래스 래퍼.
class _TourGlassPanel extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color fillColor;
  final Color borderColor;
  final List<BoxShadow>? boxShadow;
  final Widget child;

  const _TourGlassPanel({
    required this.borderRadius,
    required this.fillColor,
    required this.borderColor,
    this.boxShadow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: fillColor,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor),
      boxShadow: boxShadow,
    );

    if (kIsWeb) {
      return DecoratedBox(
        decoration: decoration,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}

class _CoachmarkBodyText extends StatelessWidget {
  final String body;
  final List<String> emphasisWords;

  const _CoachmarkBodyText({
    required this.body,
    required this.emphasisWords,
  });

  static const _bodyStyle = TextStyle(
    fontSize: 12.5,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: Color(0xFF334155),
  );

  static const _emphasisStyle = TextStyle(
    fontSize: 12.5,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: CoachmarkSpotlightTour.cyanTint,
  );

  static List<TextSpan> _buildSpans(String text, List<String> words) {
    if (words.isEmpty) {
      return [TextSpan(text: text, style: _bodyStyle)];
    }

    final sorted = [...words]..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(sorted.map(RegExp.escape).join('|'));
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, match.start),
          style: _bodyStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: _emphasisStyle,
      ));
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: _bodyStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: _buildSpans(body, emphasisWords)),
    );
  }
}

class _TourTapHintChip extends StatelessWidget {
  const _TourTapHintChip();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: _TourGlassPanel(
          borderRadius: BorderRadius.circular(20),
          fillColor: Colors.black.withValues(alpha: kIsWeb ? 0.52 : 0.40),
          borderColor: Colors.white.withValues(alpha: 0.20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              '💡 화면 아무 곳이나 터치하면 다음',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTourTooltip extends StatelessWidget {
  final String title;
  final String body;
  final List<String> emphasisWords;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onSkip;

  const _GlassTourTooltip({
    required this.title,
    required this.body,
    required this.emphasisWords,
    required this.stepIndex,
    required this.totalSteps,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _TourGlassPanel(
      borderRadius: BorderRadius.circular(16),
      fillColor: Colors.white.withValues(alpha: kIsWeb ? 0.96 : 0.9),
      borderColor: Colors.white.withValues(alpha: 0.6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _CoachmarkBodyText(
                    body: body,
                    emphasisWords: emphasisWords,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '다음 (${stepIndex + 1}/$totalSteps)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CoachmarkSpotlightTour.cyanTint,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 16,
                        color: CoachmarkSpotlightTour.cyanTint,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
