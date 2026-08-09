import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../dashboard/dashboard_palette.dart';

/// 글래스 톤 검색 로딩 인디케이터.
class DictionaryGlassSearchLoader extends StatefulWidget {
  final Color accent;
  final String message;

  const DictionaryGlassSearchLoader({
    super.key,
    required this.accent,
    this.message = '검색 중…',
  });

  @override
  State<DictionaryGlassSearchLoader> createState() =>
      _DictionaryGlassSearchLoaderState();
}

class _DictionaryGlassSearchLoaderState extends State<DictionaryGlassSearchLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final pulse = 0.92 + math.sin(_controller.value * math.pi * 2) * 0.08;
              return Transform.scale(
                scale: pulse,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0x38FFFFFF),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.62),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _GlassLoaderArcPainter(
                            progress: _controller.value,
                            accent: widget.accent,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.message,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: DashboardPalette.navy.withValues(alpha: 0.55),
                      letterSpacing: -0.15,
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

class _GlassLoaderArcPainter extends CustomPainter {
  final double progress;
  final Color accent;

  _GlassLoaderArcPainter({
    required this.progress,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    const stroke = 2.8;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.12);

    canvas.drawCircle(center, radius, track);

    final sweep = math.pi * 1.35;
    final start = progress * math.pi * 2;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [
          accent.withValues(alpha: 0.05),
          accent.withValues(alpha: 0.45),
          accent,
        ],
        stops: const [0.0, 0.55, 1.0],
        transform: GradientRotation(start),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arc,
    );

    final dotAngle = start + sweep;
    final dotCenter = Offset(
      center.dx + radius * math.cos(dotAngle),
      center.dy + radius * math.sin(dotAngle),
    );
    canvas.drawCircle(
      dotCenter,
      2.6,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassLoaderArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

/// 검색 결과 카드 등장 — fade + slide, 인덱스별 stagger.
class DictionarySearchResultEntrance extends StatefulWidget {
  final int index;
  final Widget child;

  const DictionarySearchResultEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<DictionarySearchResultEntrance> createState() =>
      _DictionarySearchResultEntranceState();
}

class _DictionarySearchResultEntranceState
    extends State<DictionarySearchResultEntrance>
    with SingleTickerProviderStateMixin {
  static const _maxStaggerIndex = 7;
  static const _staggerMs = 45;
  static const _durationMs = 340;

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(curve);

    final delay = _staggerMs * widget.index.clamp(0, _maxStaggerIndex);
    if (delay == 0) {
      _controller.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// 검색 결과 패널 전환 — 로딩 ↔ 결과 fade.
class DictionarySearchResultsTransition extends StatelessWidget {
  final Widget child;

  const DictionarySearchResultsTransition({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      child: child,
    );
  }
}
