import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/my_page_report_providers.dart';

// ── Aviation stamp palette ───────────────────────────────────

abstract final class AviationStampPalette {
  static const inkNavy = Color(0xFF1B365D);
  static const inkBurgundy = Color(0xFF8B0000);
  static const inkEmerald = Color(0xFF004B23);
  static const inkGold = Color(0xFFB8860B);
  static const ghost = Color(0xFFB8B2A8);

  static const inkColors = [inkNavy, inkBurgundy, inkEmerald, inkGold];

  static const ringTopTexts = [
    'JSPEAK CERTIFIED · CREW ONLY',
    'PASSED · FLIGHT APPROVED',
    'OFFICIAL CREW SEAL · JSPEAK',
    'AVIATION TRAINING · VERIFIED',
  ];

  static const ringBottomTexts = [
    'PASSED · FLIGHT APPROVED',
    'CREW ONLY · JSPEAK',
    'IN-FLIGHT READY · CERTIFIED',
    'MISSION CLEAR · STAMPED',
  ];
}

enum AviationStampShape {
  doubleCircle,
  scallopedPostage,
  doubleOctagon,
  classicShield,
}

class AviationStampSpec {
  final AviationStampShape shape;
  final Color ink;
  final String ringTop;
  final String ringBottom;
  final double rotation;

  const AviationStampSpec({
    required this.shape,
    required this.ink,
    required this.ringTop,
    required this.ringBottom,
    required this.rotation,
  });
}

AviationStampSpec aviationStampSpecFor(String badgeId, int index) {
  const defaultRotations = [-0.12, 0.09, -0.07, 0.11, -0.1, 0.08, -0.06, 0.13, -0.08];
  const shapes = AviationStampShape.values;
  const deg = math.pi / 180;

  final inkOverride = switch (badgeId) {
    'first_step' => const Color(0xFF005F3B),
    'situation_guardian' => const Color(0xFF8B0000),
    'perfect_voice' => const Color(0xFF1B365D),
    'first_class_multi_crew' => const Color(0xFFB8860B),
    _ => null,
  };

  final rotationOverride = switch (badgeId) {
    'first_step' => -6 * deg,
    'situation_guardian' => 8 * deg,
    'perfect_voice' => -4 * deg,
    'first_class_multi_crew' => 5 * deg,
    _ => null,
  };

  return AviationStampSpec(
    shape: switch (badgeId) {
      'first_step' => AviationStampShape.scallopedPostage,
      'perfect_voice' => AviationStampShape.doubleCircle,
      'polite_master' => AviationStampShape.doubleOctagon,
      'tone_breaker' => AviationStampShape.classicShield,
      'situation_guardian' => AviationStampShape.doubleCircle,
      'all_weather_japanese' => AviationStampShape.scallopedPostage,
      'inflight_talk_king' => AviationStampShape.classicShield,
      'walking_dictionary' => AviationStampShape.doubleOctagon,
      'first_class_multi_crew' => AviationStampShape.scallopedPostage,
      _ => shapes[index % shapes.length],
    },
    ink: inkOverride ??
        AviationStampPalette.inkColors[index % AviationStampPalette.inkColors.length],
    ringTop: AviationStampPalette.ringTopTexts[
        index % AviationStampPalette.ringTopTexts.length],
    ringBottom: AviationStampPalette.ringBottomTexts[
        index % AviationStampPalette.ringBottomTexts.length],
    rotation: rotationOverride ??
        defaultRotations[index % defaultRotations.length],
  );
}

/// 빈티지 항공 직인 — 획득 칭호.
class AviationTitleStamp extends StatelessWidget {
  final PassportTitleBadge badge;
  final int index;
  final double size;

  const AviationTitleStamp({
    super.key,
    required this.badge,
    required this.index,
    this.size = 112,
  });

  @override
  Widget build(BuildContext context) {
    final spec = aviationStampSpecFor(badge.id, index);
    final scale = size / 112;

    return Transform.rotate(
      angle: spec.rotation,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AviationStampPainter(
            shape: spec.shape,
            ink: spec.ink,
            fillOpacity: 0.08,
            strokeWidth: 2 * scale.clamp(0.75, 1.0),
            unlocked: true,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _ArcTextRingPainter(
                  topText: spec.ringTop,
                  bottomText: spec.ringBottom,
                  ink: spec.ink,
                  fontSize: 5.2 * scale,
                  bottomFontSize: 5 * scale,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(18 * scale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      badge.emoji,
                      style: TextStyle(
                        fontSize: 20 * scale,
                        height: 1,
                        color: spec.ink.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      badge.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5 * scale,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.15,
                        color: spec.ink.withValues(alpha: 0.94),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 미획득 — 점선 틀 + 잠금.
class AviationLockedStamp extends StatelessWidget {
  final PassportTitleBadge badge;
  final int index;
  final double size;

  const AviationLockedStamp({
    super.key,
    required this.badge,
    required this.index,
    this.size = 112,
  });

  @override
  Widget build(BuildContext context) {
    final spec = aviationStampSpecFor(badge.id, index);
    final scale = size / 112;

    return Transform.rotate(
      angle: spec.rotation * 0.35,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: AviationDashedStampPainter(
            shape: spec.shape,
            color: AviationStampPalette.ghost.withValues(alpha: 0.6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_open_rounded,
                size: 13 * scale,
                color: AviationStampPalette.ghost.withValues(alpha: 0.75),
              ),
              SizedBox(height: 4 * scale),
              Text(
                badge.emoji,
                style: TextStyle(
                  fontSize: 16 * scale,
                  color: AviationStampPalette.ghost.withValues(alpha: 0.55),
                ),
              ),
              SizedBox(height: 3 * scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                child: Text(
                  badge.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AviationStampPalette.ghost.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AviationStampPainter extends CustomPainter {
  final AviationStampShape shape;
  final Color ink;
  final double fillOpacity;
  final double strokeWidth;
  final bool unlocked;

  _AviationStampPainter({
    required this.shape,
    required this.ink,
    required this.fillOpacity,
    required this.strokeWidth,
    required this.unlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final fill = ink.withValues(alpha: fillOpacity);
    final stroke = Paint()
      ..color = ink.withValues(alpha: unlocked ? 0.88 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    switch (shape) {
      case AviationStampShape.doubleCircle:
        _paintDoubleCircle(canvas, rect, fill, stroke);
      case AviationStampShape.scallopedPostage:
        _paintScalloped(canvas, center, size.shortestSide / 2 - 3, fill, stroke);
      case AviationStampShape.doubleOctagon:
        _paintDoubleOctagon(canvas, rect, fill, stroke);
      case AviationStampShape.classicShield:
        _paintShield(canvas, rect, fill, stroke);
    }
  }

  void _paintDoubleCircle(Canvas canvas, Rect rect, Color fill, Paint stroke) {
    final outer = rect.deflate(4);
    canvas.drawOval(outer, Paint()..color = fill);
    canvas.drawOval(outer, stroke);
    canvas.drawOval(outer.deflate(9), stroke..strokeWidth = stroke.strokeWidth * 0.75);
  }

  void _paintScalloped(
    Canvas canvas,
    Offset center,
    double radius,
    Color fill,
    Paint stroke,
  ) {
    final path = _scallopedPath(center, radius, 16);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, stroke);
    canvas.drawPath(
      _scallopedPath(center, radius - 7, 16),
      stroke..strokeWidth = stroke.strokeWidth * 0.75,
    );
  }

  void _paintDoubleOctagon(Canvas canvas, Rect rect, Color fill, Paint stroke) {
    final outer = _octagonPath(rect.deflate(4));
    canvas.drawPath(outer, Paint()..color = fill);
    canvas.drawPath(outer, stroke);
    canvas.drawPath(
      _octagonPath(rect.deflate(14)),
      stroke..strokeWidth = stroke.strokeWidth * 0.75,
    );
  }

  void _paintShield(Canvas canvas, Rect rect, Color fill, Paint stroke) {
    final path = _shieldPath(rect.deflate(4));
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, stroke);
    canvas.drawPath(
      _shieldPath(rect.deflate(14)),
      stroke..strokeWidth = stroke.strokeWidth * 0.75,
    );
  }

  Path _scallopedPath(Offset center, double radius, int lobes) {
    final path = Path();
    for (var i = 0; i <= lobes; i++) {
      final t = i / lobes * math.pi * 2;
      final r = radius + (i.isEven ? 2.5 : 0);
      final x = center.dx + math.cos(t) * r;
      final y = center.dy + math.sin(t) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _octagonPath(Rect rect) {
    return _regularPolygonPath(rect.center, rect.shortestSide / 2, 8);
  }

  Path _regularPolygonPath(Offset center, double radius, int sides) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / sides);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _shieldPath(Rect rect) {
    final w = rect.width;
    final h = rect.height;
    final left = rect.left;
    final top = rect.top;
    return Path()
      ..moveTo(left + w * 0.5, top)
      ..lineTo(left + w * 0.92, top + h * 0.22)
      ..lineTo(left + w * 0.92, top + h * 0.55)
      ..quadraticBezierTo(
        left + w * 0.5,
        top + h * 0.98,
        left + w * 0.08,
        top + h * 0.55,
      )
      ..lineTo(left + w * 0.08, top + h * 0.22)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _AviationStampPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.shape != shape;
}

/// 스탬프 원형 테두리를 따라 곡선으로 렌더링하는 링 텍스트.
class _ArcTextRingPainter extends CustomPainter {
  final String topText;
  final String bottomText;
  final Color ink;
  final double fontSize;
  final double bottomFontSize;

  const _ArcTextRingPainter({
    required this.topText,
    required this.bottomText,
    required this.ink,
    required this.fontSize,
    required this.bottomFontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - fontSize * 1.1;

    _paintArcText(
      canvas: canvas,
      center: center,
      radius: radius,
      text: topText,
      startAngle: -math.pi * 0.82,
      sweepAngle: math.pi * 0.64,
      fontSize: fontSize,
      alpha: 0.72,
      upright: true,
    );
    _paintArcText(
      canvas: canvas,
      center: center,
      radius: radius - 1,
      text: bottomText,
      startAngle: math.pi * 0.18,
      sweepAngle: math.pi * 0.64,
      fontSize: bottomFontSize,
      alpha: 0.68,
      upright: false,
    );
  }

  void _paintArcText({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required String text,
    required double startAngle,
    required double sweepAngle,
    required double fontSize,
    required double alpha,
    required bool upright,
  }) {
    if (text.isEmpty) return;

    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.35,
      fontFamily: 'Georgia',
      color: ink.withValues(alpha: alpha),
    );

    final chars = text.split('');
    final angleStep = sweepAngle / chars.length;

    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      if (char.trim().isEmpty) continue;

      final angle = startAngle + angleStep * (i + 0.5);
      final pos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final tp = TextPainter(
        text: TextSpan(text: char, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(upright ? angle + math.pi / 2 : angle - math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ArcTextRingPainter oldDelegate) =>
      oldDelegate.topText != topText ||
      oldDelegate.bottomText != bottomText ||
      oldDelegate.ink != ink;
}

/// 점선 외곽 (미획득).
class AviationDashedStampPainter extends CustomPainter {
  final AviationStampShape shape;
  final Color color;

  AviationDashedStampPainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _shapeOutlinePath(rect);
    _drawDashedPath(canvas, path, color);
  }

  Path _shapeOutlinePath(Rect rect) {
    switch (shape) {
      case AviationStampShape.doubleCircle:
        return Path()..addOval(rect.deflate(8));
      case AviationStampShape.scallopedPostage:
        return _scallopedPath(rect.center, rect.shortestSide / 2 - 6, 16);
      case AviationStampShape.doubleOctagon:
        return _octagonPath(rect.deflate(8));
      case AviationStampShape.classicShield:
        return _shieldPath(rect.deflate(8));
    }
  }

  Path _scallopedPath(Offset center, double radius, int lobes) {
    final path = Path();
    for (var i = 0; i <= lobes; i++) {
      final t = i / lobes * math.pi * 2;
      final r = radius + 2.5 * math.sin(t * lobes);
      final x = center.dx + math.cos(t) * r;
      final y = center.dy + math.sin(t) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _octagonPath(Rect rect) {
    return _regularPolygonPath(rect.center, rect.shortestSide / 2, 8);
  }

  Path _regularPolygonPath(Offset center, double radius, int sides) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / sides);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _shieldPath(Rect rect) {
    final w = rect.width;
    final h = rect.height;
    final left = rect.left;
    final top = rect.top;
    return Path()
      ..moveTo(left + w * 0.5, top)
      ..lineTo(left + w * 0.92, top + h * 0.22)
      ..lineTo(left + w * 0.92, top + h * 0.55)
      ..quadraticBezierTo(
        left + w * 0.5,
        top + h * 0.98,
        left + w * 0.08,
        top + h * 0.55,
      )
      ..lineTo(left + w * 0.08, top + h * 0.22)
      ..close();
  }

  void _drawDashedPath(Canvas canvas, Path path, Color color) {
    const dash = 4.0;
    const gap = 3.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant AviationDashedStampPainter oldDelegate) => false;
}
