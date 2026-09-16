import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/active5_layout.dart';

/// 웹(GitHub Pages 등) — 브라우저 창 크기와 무관하게 Active 5 논리 해상도로 고정.
/// Chrome `--window-size=960,600` 미리보기와 동일한 레이아웃·비율(확대하지 않음).
class Active5WebViewport extends StatelessWidget {
  final Widget child;

  const Active5WebViewport({super.key, required this.child});

  static const Size _deviceSize = Active5Layout.previewLandscape;

  static MediaQueryData _framedMediaQuery(BuildContext hostContext) {
    final host = MediaQuery.of(hostContext);
    return MediaQueryData(
      size: _deviceSize,
      devicePixelRatio: 1,
      textScaler: host.textScaler.clamp(
        minScaleFactor: 0.95,
        maxScaleFactor: 1.15,
      ),
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
    if (!kIsWeb) return child;

    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) {
            return child;
          }

          // 큰 모니터에서도 960×600을 넘어 확대하지 않음 → 로컬 Chrome 창과 동일.
          final scale = math.min(
            1.0,
            math.min(
              maxW / _deviceSize.width,
              maxH / _deviceSize.height,
            ),
          );
          final frameW = _deviceSize.width * scale;
          final frameH = _deviceSize.height * scale;

          return Center(
            child: SizedBox(
              width: frameW,
              height: frameH,
              child: FittedBox(
                fit: BoxFit.fill,
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
            ),
          );
        },
      ),
    );
  }
}
