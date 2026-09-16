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
        // 웹: Active5WebViewport가 size를 고정한 뒤, 그 안에서만 textScaler 적용.
        // (바깥 MediaQuery를 그대로 copy하면 브라우저 전체 크기로 다시 덮어씀)
        return Active5WebViewport(
          child: Builder(
            builder: (context) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
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
            },
          ),
        );
      },
    );
  }
}
