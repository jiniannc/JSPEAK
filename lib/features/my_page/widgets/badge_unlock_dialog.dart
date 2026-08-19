import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/title_badge.dart';
import 'title_badge_hero_fx.dart';
import 'title_badge_tile.dart';

const List<Color> _kConfettiColors = [
  BadgeGoldTheme.champagne,
  BadgeGoldTheme.amber,
  Colors.white,
  Color(0xFFFDE68A),
  Color(0xFFF472B6),
  Color(0xFF60A5FA),
];

/// 신규 칭호 획득 축하 다이얼로그 — 바운스 + 회전 글로우 + 컨페티 + 햅틱.
Future<void> showBadgeUnlockDialog(BuildContext context, TitleBadge badge) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) {
      return BadgeUnlockDialog(badge: badge);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class BadgeUnlockDialog extends StatefulWidget {
  final TitleBadge badge;

  const BadgeUnlockDialog({super.key, required this.badge});

  @override
  State<BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends State<BadgeUnlockDialog>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scale;
  late final AnimationController _confettiController;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // 0 -> 1.1 -> 1.0 오버슈트 바운스: elasticOut 커브 자체가 목표값을 넘겼다가 되돌아온다.
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _particles = _generateParticles(30);

    _bounceController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  List<_ConfettiParticle> _generateParticles(int count) {
    final rnd = math.Random();
    return List.generate(count, (i) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.4;
      return _ConfettiParticle(
        angle: angle,
        speed: 150 + rnd.nextDouble() * 150,
        size: 5 + rnd.nextDouble() * 5,
        color: _kConfettiColors[rnd.nextInt(_kConfettiColors.length)],
        spin: (rnd.nextDouble() - 0.5) * 10,
        startDelay: rnd.nextDouble() * 0.18,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final stampHeight = kTitleBadgePopupStampHeight;
    final stampWidth = badge.stampWidthForHeight(stampHeight);
    final heroAreaWidth = stampWidth + 48;
    final heroAreaHeight = stampHeight + 48;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: SizedBox(
          width: math.max(400.0, heroAreaWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: heroAreaWidth,
                height: heroAreaHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _confettiController,
                      builder: (context, _) => CustomPaint(
                        size: Size(heroAreaWidth, heroAreaHeight),
                        painter: _ConfettiPainter(
                          particles: _particles,
                          t: _confettiController.value,
                        ),
                      ),
                    ),
                    TitleBadgeHeroFx(
                      badge: badge,
                      height: stampHeight,
                      enableEntranceBounce: false,
                      externalScale: _scale,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'NEW TITLE UNLOCKED!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: BadgeGoldTheme.champagne,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: BadgeGoldTheme.amberDeep,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
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

class _ConfettiParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
  final double startDelay;

  const _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
    required this.startDelay,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double t;

  const _ConfettiPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    const gravity = 280.0;

    for (final p in particles) {
      final span = (1 - p.startDelay);
      if (span <= 0) continue;
      final localT = ((t - p.startDelay) / span).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final dx = math.cos(p.angle) * p.speed * localT;
      final dy = math.sin(p.angle) * p.speed * localT +
          0.5 * gravity * localT * localT;
      final pos = center + Offset(dx, dy);
      final opacity = (1 - localT).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * localT * math.pi);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 1.8,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
