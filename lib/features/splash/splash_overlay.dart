import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/assets/app_asset_preloader.dart';
import 'splash_brand_config.dart';
import 'splash_screen.dart';
import 'widgets/splash_brand.dart';

/// 앱 최초 구동 시 전체화면 스플래시를 띄우고, 콘텐츠·브랜드 준비 후 페이드아웃.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key});

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final DateTime _startedAt;
  bool _dismissScheduled = false;
  bool _visible = true;
  bool _brandReady = false;
  bool _brandPrecacheStarted = false;
  Timer? _minTimer;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _fade = AnimationController(
      vsync: this,
      duration: SplashBrandConfig.fadeOutDuration,
      value: 1,
    );
    _minTimer = Timer(SplashBrandConfig.minDisplayDuration, _tryDismiss);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheStartupAssets();
      _tryDismiss();
    });
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _precacheStartupAssets() async {
    if (_brandPrecacheStarted) return;
    _brandPrecacheStarted = true;

    try {
      await Future.wait([
        if (SplashBrandConfig.kind == SplashBrandKind.image)
          SplashBrandAssets.precacheImageAsset(context),
        AppAssetPreloader.warmUp(context),
      ]);
    } catch (_) {
      // 디코드 실패 시에도 스플래시가 영구 고정되지 않도록 진행한다.
    }

    if (!mounted) return;
    setState(() => _brandReady = true);
    _tryDismiss();
  }

  void _tryDismiss() {
    if (_dismissScheduled || !_visible) return;

    final content = ref.read(contentProvider);
    if (!content.hasValue) return;
    if (!_brandReady) return;

    final elapsed = DateTime.now().difference(_startedAt);
    if (elapsed < SplashBrandConfig.minDisplayDuration) {
      _minTimer?.cancel();
      _minTimer = Timer(
        SplashBrandConfig.minDisplayDuration - elapsed,
        _tryDismiss,
      );
      return;
    }

    _dismissScheduled = true;
    _fade.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(contentProvider, (previous, next) {
      if (next.hasValue) _tryDismiss();
    });

    if (!_visible) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: _dismissScheduled,
      child: FadeTransition(
        opacity: _fade,
        child: const Material(
          type: MaterialType.transparency,
          child: SplashScreen(),
        ),
      ),
    );
  }
}
