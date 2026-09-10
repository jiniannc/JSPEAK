import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// JSPEAK 옆 미니 언어 뱃지 — en1 / jp1 / cn1 PNG (1000×1000).
class LanguageHeaderBadge extends StatefulWidget {
  const LanguageHeaderBadge({
    super.key,
    required this.selectedLanguage,
  });

  final String selectedLanguage;

  /// 표시 크기 — 원본 1:1 비율 유지.
  static const displaySize = 25.0;
  static const switchDuration = Duration(milliseconds: 320);

  /// 1000px → ~25px 다운스케일 선명도 (DPR × 2.5, 최소 100px 디코드).
  static const _cacheMultiplier = 2.5;
  static const _minDecodeSize = 100;
  static const _maxDecodeSize = 240;

  static const assets = <String, String>{
    'English': 'assets/images/languagebadge_en1.png',
    'Japanese': 'assets/images/languagebadge_jp1.png',
    'Chinese': 'assets/images/languagebadge_cn1.png',
  };

  static int? _cachedDecodeSide;
  static final Map<String, ImageProvider> _providers = {};

  static String assetFor(String language) =>
      assets[language] ?? assets['English']!;

  static int decodeSideFor(double devicePixelRatio) {
    return (displaySize * devicePixelRatio * _cacheMultiplier)
        .round()
        .clamp(_minDecodeSize, _maxDecodeSize);
  }

  /// precache·표시 — 동일 [ImageProvider] 인스턴스.
  static ImageProvider providerFor(String language, int decodeSide) {
    if (_cachedDecodeSide != decodeSide) {
      _providers.clear();
      _cachedDecodeSide = decodeSide;
    }
    return _providers.putIfAbsent(
      language,
      () => ResizeImage(
        AssetImage(assetFor(language)),
        width: decodeSide,
        height: decodeSide,
      ),
    );
  }

  static Future<void> precacheAll(BuildContext context) {
    final side = decodeSideFor(MediaQuery.devicePixelRatioOf(context));
    return Future.wait(
      assets.keys.map(
        (language) => precacheImage(providerFor(language, side), context),
      ),
    );
  }

  @override
  State<LanguageHeaderBadge> createState() => _LanguageHeaderBadgeState();
}

enum _IdleMotion { nod, shake, bounce }

class _LanguageHeaderBadgeState extends State<LanguageHeaderBadge>
    with SingleTickerProviderStateMixin {
  static const _idleAnimDuration = Duration(milliseconds: 520);
  static const _idleMinDelay = Duration(seconds: 5);
  static const _idleMaxDelay = Duration(seconds: 10);

  final math.Random _random = math.Random();

  late final AnimationController _idle;
  Timer? _idleTimer;
  _IdleMotion _motion = _IdleMotion.nod;
  int? _warmedDecodeSide;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: _idleAnimDuration);
    _scheduleNextIdle();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmLayers());
  }

  @override
  void didUpdateWidget(covariant LanguageHeaderBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLanguage != widget.selectedLanguage) {
      _playSwitchMotion();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warmLayers();
  }

  Future<void> _warmLayers() async {
    if (!mounted) return;
    final side =
        LanguageHeaderBadge.decodeSideFor(MediaQuery.devicePixelRatioOf(context));
    if (_warmedDecodeSide == side) return;
    _warmedDecodeSide = side;
    try {
      await LanguageHeaderBadge.precacheAll(context);
    } catch (_) {
      // 디코드 실패해도 표시는 시도한다.
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idle.dispose();
    super.dispose();
  }

  void _scheduleNextIdle() {
    _idleTimer?.cancel();
    final minMs = _idleMinDelay.inMilliseconds;
    final maxMs = _idleMaxDelay.inMilliseconds;
    final delayMs = minMs + _random.nextInt(maxMs - minMs);
    _idleTimer = Timer(Duration(milliseconds: delayMs), _playRandomIdle);
  }

  _IdleMotion _pickRandomMotion() =>
      _IdleMotion.values[_random.nextInt(_IdleMotion.values.length)];

  Future<void> _runMotion() async {
    if (!mounted) return;
    _idle.stop();
    await _idle.forward(from: 0);
    if (!mounted) return;
    await _idle.reverse();
  }

  Future<void> _playRandomIdle() async {
    if (!mounted) return;
    _motion = _pickRandomMotion();
    await _runMotion();
    if (!mounted) return;
    _scheduleNextIdle();
  }

  Future<void> _playSwitchMotion() async {
    _idleTimer?.cancel();
    _motion = _pickRandomMotion();
    await _runMotion();
    if (!mounted) return;
    _scheduleNextIdle();
  }

  Widget _wrapIdleMotion(Widget child, double t) {
    final envelope = math.sin(t * math.pi).clamp(0.0, 1.0);
    switch (_motion) {
      case _IdleMotion.nod:
        final angle = math.sin(t * math.pi * 2.4) * 0.16 * envelope;
        return Transform.rotate(
          angle: angle,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      case _IdleMotion.shake:
        final dx = math.sin(t * math.pi * 7.5) * 1.6 * envelope;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      case _IdleMotion.bounce:
        final pop = math.sin(t * math.pi);
        return Transform.translate(
          offset: Offset(0, -pop * 2.2),
          child: Transform.scale(
            scale: 1 + (pop * 0.13),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
    }
  }

  Widget _badgeImage(String language, int decodeSide) {
    return Image(
      image: LanguageHeaderBadge.providerFor(language, decodeSide),
      width: LanguageHeaderBadge.displaySize,
      height: LanguageHeaderBadge.displaySize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
    );
  }

  Widget _buildLanguageLayers(int decodeSide) {
    final selected = widget.selectedLanguage;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        for (final language in LanguageHeaderBadge.assets.keys)
          AnimatedOpacity(
            key: ValueKey<String>('badge-layer-$language'),
            opacity: language == selected ? 1 : 0,
            duration: LanguageHeaderBadge.switchDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: language == selected ? 1 : 0.88,
              duration: LanguageHeaderBadge.switchDuration,
              curve: Curves.easeOutBack,
              alignment: Alignment.bottomCenter,
              child: _badgeImage(language, decodeSide),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final decodeSide =
        LanguageHeaderBadge.decodeSideFor(MediaQuery.devicePixelRatioOf(context));

    return SizedBox(
      width: LanguageHeaderBadge.displaySize,
      height: LanguageHeaderBadge.displaySize,
      child: AnimatedBuilder(
        animation: _idle,
        builder: (context, child) {
          if (_idle.value <= 0) return child!;
          return _wrapIdleMotion(child!, _idle.value);
        },
        child: _buildLanguageLayers(decodeSide),
      ),
    );
  }
}
