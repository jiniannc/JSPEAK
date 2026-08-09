import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ScoreCelebrationTier {
  none,
  excellent,
  perfect;

  static ScoreCelebrationTier fromPercent(int percent) {
    if (percent >= 100) return perfect;
    if (percent >= 90) return excellent;
    return none;
  }

  int get burstCount => switch (this) {
        perfect => 3,
        excellent => 2,
        none => 0,
      };

  int get particlesPerBurst => switch (this) {
        perfect => 48,
        excellent => 30,
        none => 0,
      };

  Duration get duration => switch (this) {
        perfect => const Duration(milliseconds: 3400),
        excellent => const Duration(milliseconds: 2800),
        none => Duration.zero,
      };

  double get particleOpacity => switch (this) {
        perfect => 0.95,
        excellent => 0.78,
        none => 0,
      };

  double get ringOpacity => switch (this) {
        perfect => 0.72,
        excellent => 0.48,
        none => 0,
      };

  List<double> get ringBurstTimes => switch (this) {
        perfect => const [0.04, 0.18, 0.32],
        excellent => const [0.06, 0.22],
        none => const [],
      };
}

/// 90%+ 달성 시 전체 화면 축하 오버레이 — 100%는 풀 폭죽, 90~99%는 소프트 버스트.
class ScoreCelebrationOverlay extends StatefulWidget {
  final ScoreCelebrationTier tier;

  const ScoreCelebrationOverlay({super.key, required this.tier});

  @override
  State<ScoreCelebrationOverlay> createState() =>
      _ScoreCelebrationOverlayState();
}

class _ScoreCelebrationOverlayState extends State<ScoreCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_FireworkSpark> _sparks;

  @override
  void initState() {
    super.initState();
    final tier = widget.tier;
    final random = math.Random(tier == ScoreCelebrationTier.perfect ? 42 : 91);
    _sparks = [
      for (var burst = 0; burst < tier.burstCount; burst++)
        for (var i = 0; i < tier.particlesPerBurst; i++)
          _FireworkSpark.random(
            random,
            burst,
            soft: tier == ScoreCelebrationTier.excellent,
          ),
    ];
    _controller = AnimationController(
      vsync: this,
      duration: tier.duration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _FireworksPainter(
                progress: _controller.value,
                sparks: _sparks,
                canvasSize: canvasSize,
                tier: widget.tier,
              ),
              size: canvasSize,
            );
          },
        );
      },
    );
  }
}

class _FireworkSpark {
  final Offset origin;
  final Offset velocity;
  final Color color;
  final double size;
  final double rotation;
  final double spin;
  final double delay;
  final bool isRect;

  const _FireworkSpark({
    required this.origin,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.delay,
    required this.isRect,
  });

  factory _FireworkSpark.random(
    math.Random random,
    int burst, {
    bool soft = false,
  }) {
    final palette = soft
        ? const [
            Color(0xFF10B981),
            Color(0xFF06B6D4),
            Color(0xFFFBBF24),
            Color(0xFFCA8A04),
            Color(0xFF0D9488),
            Color(0xFF38BDF8),
          ]
        : const [
            Color(0xFF10B981),
            Color(0xFF06B6D4),
            Color(0xFFF59E0B),
            Color(0xFF9333EA),
            Color(0xFFF43F5E),
            Color(0xFF3B82F6),
            Color(0xFFFBBF24),
          ];
    final anchorX = 0.12 + random.nextDouble() * 0.76;
    // 점수/웨이브폼이 화면 중하단에 바로 나타나므로, 두 티어 모두 폭죽이
    // 화면 상단(배리어 영역)에만 머물러 결과 카드 위를 가리지 않도록 한다.
    final anchorY = soft
        ? (burst == 0 ? 0.24 : 0.16 + burst * 0.10)
        : (burst == 0 ? 0.22 : 0.14 + burst * 0.09);
    final angle = soft
        ? -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 0.65
        : -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 0.95;
    final speed = soft
        ? 120 + random.nextDouble() * 160
        : 180 + random.nextDouble() * 260;
    return _FireworkSpark(
      origin: Offset(anchorX, anchorY),
      velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
      color: palette[random.nextInt(palette.length)],
      size: soft ? 4 + random.nextDouble() * 4.5 : 5 + random.nextDouble() * 6,
      rotation: random.nextDouble() * math.pi,
      spin: (random.nextDouble() - 0.5) * (soft ? 5 : 8),
      delay: burst * (soft ? 0.16 : 0.12) + random.nextDouble() * 0.1,
      isRect: random.nextBool(),
    );
  }
}

class _FireworksPainter extends CustomPainter {
  final double progress;
  final List<_FireworkSpark> sparks;
  final Size canvasSize;
  final ScoreCelebrationTier tier;

  const _FireworksPainter({
    required this.progress,
    required this.sparks,
    required this.canvasSize,
    required this.tier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final particleAlpha = tier.particleOpacity;
    // 결과 카드(점수 + 웨이브폼) 위로 폭죽이 흘러내려 가리지 않도록
    // perfect 티어의 중력을 excellent보다 약하게 유지한다.
    final gravityFactor = tier == ScoreCelebrationTier.excellent ? 0.52 : 0.40;

    for (final spark in sparks) {
      if (progress < spark.delay) continue;
      final localT = ((progress - spark.delay) / (1 - spark.delay)).clamp(0.0, 1.0);
      final gravity = h * gravityFactor;
      final pos = Offset(
        spark.origin.dx * w + spark.velocity.dx * localT * (w / 400),
        spark.origin.dy * h +
            spark.velocity.dy * localT * (h / 800) +
            gravity * localT * localT,
      );
      final opacity = (1 - Curves.easeIn.transform(localT)).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = spark.color.withValues(alpha: opacity * particleAlpha);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(spark.rotation + spark.spin * localT);
      if (spark.isRect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: spark.size * 1.6,
              height: spark.size * 0.9,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, spark.size * 0.7, paint);
      }
      canvas.restore();
    }

    for (final burstAt in tier.ringBurstTimes) {
      if (progress < burstAt || progress > burstAt + 0.32) continue;
      final ringT = ((progress - burstAt) / 0.32).clamp(0.0, 1.0);
      final maxRadius =
          tier == ScoreCelebrationTier.excellent ? h * 0.32 : h * 0.30;
      final ringCenterY = tier == ScoreCelebrationTier.excellent
          ? h * 0.38
          : h * 0.26;
      final radius = (24 + ringT * maxRadius).clamp(24.0, maxRadius);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (4 - ringT * 2.5).clamp(1.2, 4.0)
        ..color = Colors.white.withValues(alpha: (1 - ringT) * tier.ringOpacity);
      canvas.drawCircle(Offset(w * 0.5, ringCenterY), radius, ringPaint);
      if (tier == ScoreCelebrationTier.perfect) {
        canvas.drawCircle(
          Offset(w * 0.5, ringCenterY),
          radius * 0.72,
          ringPaint
            ..color =
                const Color(0xFFFBBF24).withValues(alpha: (1 - ringT) * 0.45),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.tier != tier;
  }
}
