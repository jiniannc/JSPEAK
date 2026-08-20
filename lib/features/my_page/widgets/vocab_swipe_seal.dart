import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 여권 단어 스와이프 탭 — 언어별 메달 + 중앙 퍼센트 + 외곽 프로그레스 링.
class VocabSwipeSeal extends StatefulWidget {
  final String language;
  final double percent;
  final bool isActive;

  const VocabSwipeSeal({
    super.key,
    required this.language,
    required this.percent,
    required this.isActive,
  });

  @override
  State<VocabSwipeSeal> createState() => _VocabSwipeSealState();
}

class _VocabSwipeSealState extends State<VocabSwipeSeal>
    with TickerProviderStateMixin {
  /// PNG 픽셀 기준 중앙 흰 구멍 직경 (1024px, r≈116).
  static const _holeDiameter = 0.228;
  /// 볼드 숫자 optical center 보정 (아래로).
  static const _holeTextYOffset = 0.016;
  /// PNG 픽셀 기준 스탬프 가시 외곽 직경 (r≈470).
  static const _badgeOuterDiameter = 0.924;
  /// 스탬프 테두리 바깥 프로그레스 링 직경.
  static const _progressRingDiameter = 0.972;
  static const _ringStrokeFraction = 0.022;
  /// 여권 페이지 안에서의 전체 표시 배율.
  static const _displayScale = 0.88;

  late final AnimationController _entrance;
  late final AnimationController _ring;
  late final AnimationController _twinkle;

  late final Animation<double> _scale;
  late final Animation<double> _tilt;
  late final Animation<double> _halo;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _scale = Tween<double>(begin: 0.76, end: 1).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.elasticOut),
    );
    _tilt = Tween<double>(begin: -0.1, end: 0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack),
    );
    _halo = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.2, 1, curve: Curves.easeOut),
      ),
    );

    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playEntrance();
      });
    }
  }

  @override
  void didUpdateWidget(covariant VocabSwipeSeal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final landed = widget.isActive && !oldWidget.isActive;
    final languageChanged =
        widget.isActive && widget.language != oldWidget.language;
    if (landed || languageChanged) {
      _playEntrance();
    } else if (!widget.isActive && oldWidget.isActive) {
      _twinkle.stop();
    }
  }

  void _playEntrance() {
    _entrance.forward(from: 0);
    _ring.forward(from: 0);
    _twinkle.repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ring.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _VocabSealTheme.of(widget.language);
    final target = (widget.percent.clamp(0, 100)) / 100;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            math.min(constraints.maxWidth, constraints.maxHeight) * _displayScale;
        final cacheSize = (size * dpr * 1.35).round().clamp(512, 1024);

        return Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_entrance, _ring, _twinkle]),
            builder: (context, _) {
              final shown = target * Curves.easeOutCubic.transform(_ring.value);
              final percentLabel = (shown * 100).round();
              final pulse = 0.55 + 0.45 * math.sin(_twinkle.value * math.pi * 2);

              return Transform.rotate(
                angle: _tilt.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        _HaloGlow(
                          color: theme.halo,
                          intensity: _halo.value * 0.75,
                          outerSize: size * _progressRingDiameter,
                        ),
                        CustomPaint(
                          size: Size.square(size),
                          painter: _OuterProgressRingPainter(
                            progress: shown,
                            theme: theme,
                            ringDiameter: _progressRingDiameter,
                            strokeFraction: _ringStrokeFraction,
                            pulse: pulse,
                          ),
                        ),
                        _BadgeImage(
                          assetPath: theme.assetPath,
                          size: size,
                          cacheSize: cacheSize,
                        ),
                        CustomPaint(
                          size: Size.square(size),
                          painter: _BadgeShimmerPainter(
                            t: _twinkle.value,
                            badgeDiameter: _badgeOuterDiameter,
                            intensity: 0.42 + 0.28 * pulse,
                          ),
                        ),
                        CustomPaint(
                          size: Size.square(size),
                          painter: _SparklePainter(
                            t: _twinkle.value,
                            accent: theme.sparkle,
                            badgeDiameter: _badgeOuterDiameter,
                          ),
                        ),
                        _PercentLabel(
                          value: percentLabel,
                          theme: theme,
                          holeDiameter: _holeDiameter,
                          textYOffset: size * _holeTextYOffset,
                          size: size,
                          appear: Curves.easeOutBack.transform(
                            (_ring.value * 1.1).clamp(0.0, 1.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BadgeImage extends StatelessWidget {
  const _BadgeImage({
    required this.assetPath,
    required this.size,
    required this.cacheSize,
  });

  final String assetPath;
  final double size;
  final int cacheSize;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        gaplessPlayback: true,
      ),
    );
  }
}

class _VocabSealTheme {
  final String assetPath;
  final List<Color> ringColors;
  final Color glow;
  final Color halo;
  final List<Color> textGradient;
  final Color sparkle;
  final Color trackColor;

  const _VocabSealTheme({
    required this.assetPath,
    required this.ringColors,
    required this.glow,
    required this.halo,
    required this.textGradient,
    required this.sparkle,
    required this.trackColor,
  });

  static _VocabSealTheme of(String language) {
    return switch (language) {
      'Japanese' => const _VocabSealTheme(
          assetPath: 'assets/images/badge_vocab_jp.png',
          ringColors: [
            Color(0xFFFCD34D),
            Color(0xFFF59E0B),
            Color(0xFFDB2777),
            Color(0xFFBE185D),
            Color(0xFF1D4ED8),
            Color(0xFFFCD34D),
          ],
          glow: Color(0xFFF59E0B),
          halo: Color(0xFFF472B6),
          textGradient: [
            Color(0xE6BE185D),
            Color(0xCC9D174D),
            Color(0xE6B45309),
          ],
          sparkle: Color(0xFFFFF8E1),
          trackColor: Color(0xFFFDE68A),
        ),
      'Chinese' => const _VocabSealTheme(
          assetPath: 'assets/images/badge_vocab_cn.png',
          ringColors: [
            Color(0xFFFCD34D),
            Color(0xFFDC2626),
            Color(0xFFB91C1C),
            Color(0xFFEA580C),
            Color(0xFFCA8A04),
            Color(0xFFFCD34D),
          ],
          glow: Color(0xFFEA580C),
          halo: Color(0xFFEF4444),
          textGradient: [
            Color(0xE6B91C1C),
            Color(0xCC991B1B),
            Color(0xE6C2410C),
          ],
          sparkle: Color(0xFFFFF7ED),
          trackColor: Color(0xFFFECACA),
        ),
      _ => const _VocabSealTheme(
          assetPath: 'assets/images/badge_vocab_en.png',
          ringColors: [
            Color(0xFFFCD34D),
            Color(0xFFF59E0B),
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
            Color(0xFFB45309),
            Color(0xFFFCD34D),
          ],
          glow: Color(0xFFF59E0B),
          halo: Color(0xFF60A5FA),
          textGradient: [
            Color(0xE61E3A8A),
            Color(0xCC1D4ED8),
            Color(0xE6B91C1C),
          ],
          sparkle: Color(0xFFFFFBEB),
          trackColor: Color(0xFFE2E8F0),
        ),
    };
  }
}

class _HaloGlow extends StatelessWidget {
  final Color color;
  final double intensity;
  final double outerSize;

  const _HaloGlow({
    required this.color,
    required this.intensity,
    required this.outerSize,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.28 * intensity),
                color.withValues(alpha: 0.10 * intensity),
                color.withValues(alpha: 0),
              ],
              stops: const [0.42, 0.72, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _PercentLabel extends StatelessWidget {
  final int value;
  final _VocabSealTheme theme;
  final double holeDiameter;
  final double textYOffset;
  final double size;
  final double appear;

  const _PercentLabel({
    required this.value,
    required this.theme,
    required this.holeDiameter,
    required this.textYOffset,
    required this.size,
    required this.appear,
  });

  @override
  Widget build(BuildContext context) {
    final hole = size * holeDiameter;
    return IgnorePointer(
      child: Opacity(
        opacity: appear.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, textYOffset),
          child: Transform.scale(
            scale: 0.88 + 0.12 * appear,
            child: SizedBox(
              width: hole,
              height: hole,
              child: Center(
                child: Text(
                  '$value%',
                  textAlign: TextAlign.center,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: TextStyle(
                    fontSize: hole * 0.38,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.5,
                    foreground: Paint()
                      ..shader = ui.Gradient.linear(
                        Offset(0, -hole * 0.08),
                        Offset(0, hole * 0.12),
                        theme.textGradient,
                      ),
                    shadows: [
                      Shadow(
                        color: theme.glow.withValues(alpha: 0.42),
                        blurRadius: 10,
                      ),
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.35),
                        blurRadius: 1.5,
                        offset: const Offset(0, 0.5),
                      ),
                    ],
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

class _OuterProgressRingPainter extends CustomPainter {
  final double progress;
  final _VocabSealTheme theme;
  final double ringDiameter;
  final double strokeFraction;
  final double pulse;

  _OuterProgressRingPainter({
    required this.progress,
    required this.theme,
    required this.ringDiameter,
    required this.strokeFraction,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * ringDiameter / 2;
    final stroke = size.shortestSide * strokeFraction;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = theme.trackColor.withValues(alpha: 0.55);
    canvas.drawCircle(center, radius, track);

    final idleRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.65
      ..shader = SweepGradient(
        colors: [
          theme.trackColor.withValues(alpha: 0.15),
          theme.ringColors.first.withValues(alpha: 0.35),
          theme.trackColor.withValues(alpha: 0.15),
          theme.ringColors[2].withValues(alpha: 0.28),
          theme.trackColor.withValues(alpha: 0.15),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, idleRing);

    if (progress <= 0.001) return;

    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * (1.6 + pulse * 0.35)
      ..strokeCap = StrokeCap.round
      ..color = theme.glow.withValues(alpha: 0.32 + 0.18 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, start, sweep, false, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + math.pi * 2,
        colors: theme.ringColors,
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, ring);

    final headAngle = start + sweep;
    final head = Offset(
      center.dx + math.cos(headAngle) * radius,
      center.dy + math.sin(headAngle) * radius,
    );
    final gemR = stroke * 0.48;
    canvas.drawCircle(
      head,
      gemR * 1.8,
      Paint()
        ..color = theme.glow.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      head,
      gemR,
      Paint()
        ..shader = ui.Gradient.radial(
          head,
          gemR,
          [Colors.white, theme.glow, theme.ringColors[2]],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _OuterProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}

class _BadgeShimmerPainter extends CustomPainter {
  final double t;
  final double badgeDiameter;
  final double intensity;

  _BadgeShimmerPainter({
    required this.t,
    required this.badgeDiameter,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * badgeDiameter / 2;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final travel = (t * 1.4) % 1.0;
    final bandWidth = size.shortestSide * 0.34;
    final dx = (travel - 0.15) * (size.width + bandWidth) - bandWidth * 0.5;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42 + math.sin(t * math.pi * 2) * 0.08);
    canvas.translate(-center.dx, -center.dy);

    final band = Rect.fromLTWH(dx, -12, bandWidth, size.height + 24);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        band.topLeft,
        band.topRight,
        [
          const Color(0x00FFFFFF),
          Color(0xAAFFFFFF).withValues(alpha: intensity),
          const Color(0xCCFFF7D6),
          Color(0x88FCD34D).withValues(alpha: intensity * 0.9),
          const Color(0x00FFFFFF),
        ],
        const [0, 0.28, 0.5, 0.72, 1],
      )
      ..blendMode = BlendMode.softLight;
    canvas.drawRect(band, paint);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BadgeShimmerPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.intensity != intensity;
}

class _SparklePainter extends CustomPainter {
  final double t;
  final Color accent;
  final double badgeDiameter;

  static const _anchors = <Offset>[
    Offset(-0.38, -0.40),
    Offset(0.36, -0.38),
    Offset(-0.44, -0.04),
    Offset(0.42, 0.10),
    Offset(-0.14, 0.42),
    Offset(0.16, -0.44),
    Offset(-0.28, 0.30),
    Offset(0.30, 0.32),
  ];

  _SparklePainter({
    required this.t,
    required this.accent,
    required this.badgeDiameter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rim = size.shortestSide * badgeDiameter / 2;

    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      final phase = i * 1.21;
      final twinkle =
          (math.sin(t * math.pi * 2 + phase) * 0.5 + 0.5).clamp(0.0, 1.0);
      if (twinkle < 0.08) continue;

      final pop = math.pow(twinkle, 1.4).toDouble();
      final pos = Offset(
        center.dx + anchor.dx * rim,
        center.dy + anchor.dy * rim,
      );
      final r = size.shortestSide * (0.018 + 0.020 * pop);
      final color = i.isEven ? Colors.white : accent;
      _drawSparkle(canvas, pos, r, color, 0.42 + 0.58 * pop);
    }
  }

  void _drawSparkle(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double alpha,
  ) {
    canvas.drawCircle(
      c,
      r * 1.4,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
    );

    final path = Path();
    for (var i = 0; i < 4; i++) {
      final radius = i.isEven ? r : r * 0.24;
      final a = i * math.pi / 2 - math.pi / 2;
      final p = Offset(c.dx + math.cos(a) * radius, c.dy + math.sin(a) * radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      c,
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: alpha * 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.t != t;
}
