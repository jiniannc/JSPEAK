import 'package:flutter/material.dart';

import '../../core/theme/language_palette.dart';

/// 언어별 캔버스 그라데이션 — 헤더·본문 seamless 배경.
class LanguageCanvasBackground extends StatelessWidget {
  final LanguagePalette palette;
  final Widget child;

  const LanguageCanvasBackground({
    super.key,
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(palette.canvas, Colors.white, 0.35)!,
            palette.canvas,
            Color.lerp(palette.softFill, palette.canvas, 0.55)!,
          ],
        ),
      ),
      child: child,
    );
  }
}
