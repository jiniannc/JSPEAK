import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/title_badge.dart';
import 'title_badge_tile.dart';

/// 팝업·축하 다이얼로그용 스탬프 히어로 — 후광 펄스 + 글래시 시머 + 스파클.
class TitleBadgeHeroFx extends StatefulWidget {
  final TitleBadge badge;
  final double height;
  final TitleBadgeImageProfile profile;
  final bool enableEntranceBounce;
  final Animation<double>? externalScale;
  final Animation<double>? externalRotation;

  const TitleBadgeHeroFx({
    super.key,
    required this.badge,
    required this.height,
    this.profile = TitleBadgeImageProfile.detail,
    this.enableEntranceBounce = true,
    this.externalScale,
    this.externalRotation,
  });

  @override
  State<TitleBadgeHeroFx> createState() => _TitleBadgeHeroFxState();
}

class _TitleBadgeHeroFxState extends State<TitleBadgeHeroFx>
    with TickerProviderStateMixin {
  static const _shimmerSweepMs = 800;
  static const _shimmerPauseSec = 3;
  static const _shimmerIntensity = 0.45;

  AnimationController? _bounceController;
  Animation<double>? _bounceScale;
  Animation<double>? _bounceWobble;

  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerT;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseT;

  late final List<AnimationController> _sparkleControllers;

  Timer? _shimmerKickoffTimer;
  Timer? _shimmerLoopTimer;

  bool get _useExternalMotion =>
      widget.externalScale != null || widget.externalRotation != null;

  bool get _showFx => widget.badge.isUnlocked;

  @override
  void initState() {
    super.initState();

    if (widget.enableEntranceBounce && !_useExternalMotion && _showFx) {
      _bounceController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 850),
      );
      _bounceScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _bounceController!, curve: Curves.elasticOut),
      );
      _bounceWobble = Tween<double>(begin: -0.18, end: 0).animate(
        CurvedAnimation(parent: _bounceController!, curve: Curves.elasticOut),
      );
      _bounceController!.forward();
    }

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _shimmerSweepMs),
    );
    _shimmerT = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOutCubic,
    );
    _shimmerController.addStatusListener(_onShimmerStatus);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _pulseT = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    const sparkleDurations = [1200, 1800, 2200];
    const sparklePhases = [0.0, 0.33, 0.66];
    _sparkleControllers = List.generate(
      sparkleDurations.length,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: sparkleDurations[i]),
      ),
    );

    if (_showFx) {
      _pulseController.repeat(reverse: true);
      for (var i = 0; i < _sparkleControllers.length; i++) {
        _sparkleControllers[i].value = sparklePhases[i];
        _sparkleControllers[i].repeat(reverse: true);
      }
      _shimmerKickoffTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _shimmerController.forward(from: 0);
      });
    }
  }

  void _onShimmerStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _shimmerLoopTimer?.cancel();
    _shimmerLoopTimer = Timer(
      const Duration(seconds: _shimmerPauseSec),
      () {
        if (!mounted) return;
        _shimmerController.forward(from: 0);
      },
    );
  }

  @override
  void dispose() {
    _shimmerKickoffTimer?.cancel();
    _shimmerLoopTimer?.cancel();
    _shimmerController.removeStatusListener(_onShimmerStatus);
    _bounceController?.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    for (final controller in _sparkleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showFx) {
      return TitleBadgeStamp(
        badge: widget.badge,
        height: widget.height,
        showGlow: false,
        profile: widget.profile,
      );
    }

    final stampWidth = widget.badge.stampWidthForHeight(widget.height);
    final stamp = _BadgeStampWithFx(
      badge: widget.badge,
      height: widget.height,
      width: stampWidth,
      profile: widget.profile,
      shimmerController: _shimmerController,
      shimmerT: _shimmerT,
      pulseController: _pulseController,
      pulseT: _pulseT,
      sparkleControllers: _sparkleControllers,
    );

    Widget hero = stamp;

    if (_useExternalMotion) {
      final motionSources = <Listenable>[
        if (widget.externalScale != null) widget.externalScale!,
        if (widget.externalRotation != null) widget.externalRotation!,
      ];
      hero = AnimatedBuilder(
        animation: motionSources.length == 1
            ? motionSources.first
            : Listenable.merge(motionSources),
        builder: (context, child) {
          final scale = widget.externalScale?.value ?? 1.0;
          final rotation = widget.externalRotation?.value ?? 0.0;
          return Transform.rotate(
            angle: rotation,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: hero,
      );
    } else if (_bounceController != null) {
      hero = AnimatedBuilder(
        animation: _bounceController!,
        builder: (context, child) {
          return Transform.rotate(
            angle: _bounceWobble!.value,
            child: Transform.scale(scale: _bounceScale!.value, child: child),
          );
        },
        child: hero,
      );
    }

    return SizedBox(
      width: widget.badge.stampWidthForHeight(widget.height),
      height: widget.height,
      child: hero,
    );
  }
}

class _BadgeStampWithFx extends StatelessWidget {
  final TitleBadge badge;
  final double height;
  final double width;
  final TitleBadgeImageProfile profile;
  final AnimationController shimmerController;
  final Animation<double> shimmerT;
  final AnimationController pulseController;
  final Animation<double> pulseT;
  final List<AnimationController> sparkleControllers;

  const _BadgeStampWithFx({
    required this.badge,
    required this.height,
    required this.width,
    required this.profile,
    required this.shimmerController,
    required this.shimmerT,
    required this.pulseController,
    required this.pulseT,
    required this.sparkleControllers,
  });

  static const _sparkleAlignments = [
    Alignment(0.86, -0.12),
    Alignment(-0.84, 0.18),
    Alignment(0.12, 0.86),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        shimmerController,
        pulseController,
        ...sparkleControllers,
      ]),
      builder: (context, _) {
        final pulse = pulseT.value;
        final glowScale = 0.94 + pulse * 0.10;
        final glowAlpha = 0.18 + pulse * 0.14;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: glowScale,
              child: Container(
                width: height * 0.92,
                height: height * 0.92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: BadgeGoldTheme.amber.withValues(alpha: glowAlpha),
                      blurRadius: height * 0.34,
                      spreadRadius: height * 0.06,
                    ),
                    BoxShadow(
                      color: BadgeGoldTheme.champagne
                          .withValues(alpha: glowAlpha * 0.75),
                      blurRadius: height * 0.22,
                      spreadRadius: height * 0.02,
                    ),
                  ],
                ),
              ),
            ),
            _GlassyShimmerStamp(
              imagePath: badge.imagePath,
              height: height,
              width: width,
              aspectRatio: badge.aspectRatio,
              profile: profile,
              shimmerT: shimmerT.value,
              intensity: _TitleBadgeHeroFxState._shimmerIntensity,
            ),
            for (var i = 0; i < _sparkleAlignments.length; i++)
              Align(
                alignment: _sparkleAlignments[i],
                child: _SparkleAccent(
                  t: sparkleControllers[i].value,
                  size: height * 0.11,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GlassyShimmerStamp extends StatelessWidget {
  final String imagePath;
  final double height;
  final double width;
  final double aspectRatio;
  final TitleBadgeImageProfile profile;
  final double shimmerT;
  final double intensity;

  const _GlassyShimmerStamp({
    required this.imagePath,
    required this.height,
    required this.width,
    required this.aspectRatio,
    required this.profile,
    required this.shimmerT,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    final image = TitleBadgeImage(
      imagePath: imagePath,
      height: height,
      width: width,
      aspectRatio: aspectRatio,
      profile: profile,
    );

    if (shimmerT <= 0) return image;

    final slide = -1.0 + shimmerT * 3.0;
    final soft = intensity.clamp(0.0, 1.0);

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment(-1.5 + slide, -1.5 + slide),
          end: Alignment(1.5 + slide, 1.5 + slide),
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.15 * soft),
            Colors.white.withValues(alpha: 0.65 * soft),
            Colors.white.withValues(alpha: 0.15 * soft),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        ).createShader(bounds);
      },
      child: image,
    );
  }
}

class _SparkleAccent extends StatelessWidget {
  final double t;
  final double size;

  const _SparkleAccent({
    required this.t,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(t * math.pi);
    if (wave <= 0.01) return const SizedBox.shrink();

    return Opacity(
      opacity: wave.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: wave * 1.2,
        child: Icon(
          Icons.auto_awesome_rounded,
          size: size,
          color: Color.lerp(
            Colors.white,
            BadgeGoldTheme.champagne,
            wave * 0.55,
          ),
        ),
      ),
    );
  }
}
