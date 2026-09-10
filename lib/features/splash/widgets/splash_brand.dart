import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../splash_brand_config.dart';

/// 스플래시 브랜드 PNG 로드 — precache·표시 모두 동일 디코드 크기 사용.
abstract final class SplashBrandAssets {
  static const _maxCacheWidth = 600;
  static const _cacheMultiplier = 1.75;
  static const _maxDisplayWidth = 300.0;
  static const _lottieMaxWidth = 220.0;
  static const _lottieAspect = 720 / 640;

  static double displayWidthFor(BuildContext context) {
    return math.min(MediaQuery.sizeOf(context).width * 0.56, _maxDisplayWidth);
  }

  static Size lottieSizeFor(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    var width = math.min(screen.width * 0.44, _lottieMaxWidth);
    var height = width * _lottieAspect;
    final maxHeight = screen.height * 0.34;
    if (height > maxHeight) {
      height = maxHeight;
      width = height / _lottieAspect;
    }
    return Size(width, height);
  }

  static int cacheWidthFor(double displayWidth, double devicePixelRatio) {
    return (displayWidth * devicePixelRatio * _cacheMultiplier)
        .round()
        .clamp(1, _maxCacheWidth);
  }

  static ImageProvider imageProvider(
    BuildContext context, {
    double? displayWidth,
  }) {
    final width = displayWidth ?? displayWidthFor(context);
    final cacheWidth = cacheWidthFor(
      width,
      MediaQuery.devicePixelRatioOf(context),
    );
    return ResizeImage(
      AssetImage(SplashBrandConfig.imageAsset),
      width: cacheWidth,
    );
  }

  static Future<void> precacheImageAsset(BuildContext context) async {
    if (SplashBrandConfig.kind != SplashBrandKind.image) return;
    await precacheImage(imageProvider(context), context);
  }
}

/// 스플래시 브랜드 PNG — 표시 크기에 맞춰 디코드해 계단/깨짐을 줄인다.
class _SplashBrandImage extends StatelessWidget {
  const _SplashBrandImage({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: SplashBrandAssets.imageProvider(context, displayWidth: width),
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      gaplessPlayback: true,
    );
  }
}

/// 스플래시 중앙 브랜드 영역 — PNG / Lottie / 영상 확장 지점.
class SplashBrand extends StatelessWidget {
  const SplashBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final maxWidth = SplashBrandAssets.displayWidthFor(context);

    return switch (SplashBrandConfig.kind) {
      SplashBrandKind.image => _SplashBrandImage(width: maxWidth),
      SplashBrandKind.lottie when SplashBrandConfig.lottieAsset.isNotEmpty =>
        _SplashBrandLottie(size: SplashBrandAssets.lottieSizeFor(context)),
      SplashBrandKind.video => _VideoPlaceholder(width: maxWidth),
      _ => _SplashBrandImage(width: maxWidth),
    };
  }
}

class _SplashBrandLottie extends StatelessWidget {
  const _SplashBrandLottie({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      SplashBrandConfig.lottieAsset,
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      repeat: true,
    );
  }
}

/// video_player 연동 전까지 PNG로 폴백.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return _SplashBrandImage(width: width);
  }
}
