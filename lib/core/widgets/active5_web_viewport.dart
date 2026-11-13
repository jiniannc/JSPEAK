import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../accessibility/app_accessibility.dart';
import '../config/active5_layout.dart';
import '../config/app_config.dart';

/// 웹 **데모 전용** (`JSPEAK_WEB_DEMO`) — 브라우저를 Active 5 가로(960×600)로 고정.
///
/// 반응형 웹 앱이 아니라, 기내 태블릿 UI 미리보기용입니다.
/// 로컬 `flutter run -d chrome` 기본값은 프레임 없이 창 전체를 씁니다.
class Active5WebViewport extends StatelessWidget {
  final Widget child;

  const Active5WebViewport({super.key, required this.child});

  static const Size _deviceSize = Active5Layout.previewLandscape;

  static bool get enabled => kIsWeb && AppConfig.webDemoFrame;

  static MediaQueryData _framedMediaQuery(BuildContext hostContext) {
    final host = MediaQuery.of(hostContext);
    return MediaQueryData(
      size: _deviceSize,
      devicePixelRatio: 1,
      textScaler: AppAccessibility.clampTextScaler(host.textScaler),
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
      systemGestureInsets: EdgeInsets.zero,
      platformBrightness: host.platformBrightness,
      highContrast: host.highContrast,
      disableAnimations: host.disableAnimations,
      invertColors: host.invertColors,
      accessibleNavigation: host.accessibleNavigation,
      boldText: host.boldText,
      navigationMode: host.navigationMode,
      gestureSettings: host.gestureSettings,
      displayFeatures: const [],
      supportsShowingSystemContextMenu: host.supportsShowingSystemContextMenu,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xFF0F172A),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) {
              return child;
            }

            final scale = math.min(
              1.0,
              math.min(
                maxW / _deviceSize.width,
                maxH / _deviceSize.height,
              ),
            );

            return Center(
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _deviceSize.width,
                  height: _deviceSize.height,
                  child: MediaQuery(
                    data: _framedMediaQuery(context),
                    child: ClipRect(child: child),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
