import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/active5_layout.dart';

/// 웹(GitHub Pages 등) — 브라우저 창 크기와 무관하게 Active 5 논리 해상도로 고정.
/// Chrome `--window-size=960,600` 미리보기와 동일한 비율·레이아웃.
class Active5WebViewport extends StatelessWidget {
  final Widget child;

  const Active5WebViewport({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hostLandscape = constraints.maxWidth >= constraints.maxHeight;
        final deviceSize = hostLandscape
            ? Active5Layout.previewLandscape
            : Active5Layout.previewPortrait;

        return ColoredBox(
          color: const Color(0xFF0F172A),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: deviceSize.width,
                height: deviceSize.height,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: deviceSize,
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    devicePixelRatio: 1,
                  ),
                  child: ClipRect(child: child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
