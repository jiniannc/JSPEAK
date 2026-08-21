import 'package:flutter/material.dart';

/// 문장 본문 줄 수·긴 문장 타이포 보정.
class SentenceTextLayout {
  SentenceTextLayout._();

  static const int longLineThreshold = 3;

  static int lineCount({
    required String text,
    required TextStyle style,
    required double maxWidth,
    TextAlign textAlign = TextAlign.center,
  }) {
    if (text.isEmpty || maxWidth <= 0) return 0;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    return painter.computeLineMetrics().length;
  }

  /// 3줄 이상이면 굵기·줄간격만 살짝 완화한다.
  static TextStyle adjustForLongText(
    TextStyle base, {
    required bool isLong,
  }) {
    if (!isLong) return base;

    return base.copyWith(
      fontWeight: _softenWeight(base.fontWeight),
      height: (base.height ?? 1.35) + 0.13,
    );
  }

  static FontWeight _softenWeight(FontWeight? weight) {
    final resolved = weight ?? FontWeight.w800;
    if (resolved.value >= FontWeight.w800.value) {
      return FontWeight.w700;
    }
    return resolved;
  }
}
