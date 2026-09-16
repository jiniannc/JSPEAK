import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/active5_web_viewport.dart';
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
        // Active 5 야외 사용: 시스템 글자 크기 과도 확대 방지
        final mq = MediaQuery.of(context);
        final app = MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.95,
              maxScaleFactor: 1.15,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              const TitleBadgeUnlockBannerHost(),
              const SplashOverlay(),
            ],
          ),
        );
        return Active5WebViewport(child: app);
      },
    );
  }
}
