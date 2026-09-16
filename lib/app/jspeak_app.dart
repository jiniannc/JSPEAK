import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/shell/title_badge_unlock_banner.dart';
import '../features/splash/splash_overlay.dart';
import 'router.dart';

class JspeakApp extends ConsumerWidget {
  const JspeakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            const TitleBadgeUnlockBannerHost(),
            const SplashOverlay(),
          ],
        );
      },
    );
  }
}
