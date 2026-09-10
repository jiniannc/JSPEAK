import 'package:flutter/material.dart';

import 'splash_brand_config.dart';
import 'widgets/splash_brand.dart';
import 'widgets/splash_three_dots.dart';

/// 앱 시작 전체화면 스플래시.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FBFD),
            Color(0xFFEEF6FA),
            Color(0xFFE4F0F7),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SplashBrand(),
                if (SplashBrandConfig.kind != SplashBrandKind.lottie) ...[
                  const SizedBox(height: 36),
                  const SplashThreeDots(color: Color(0xFF0755B8)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
