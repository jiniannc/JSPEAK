import 'package:flutter/material.dart';

import '../config/active5_layout.dart';

/// Active 5 · 기내·장갑 사용을 고려한 접근성 기본값.
abstract final class AppAccessibility {
  static const double minTouchTarget = Active5Layout.minTouchTarget;

  /// 시스템 글자 크기 과확대 시 고정 높이 카드 깨짐을 줄이기 위한 상한.
  static const double minTextScaleFactor = 0.95;
  static const double maxTextScaleFactor = 1.15;

  static TextScaler clampTextScaler(TextScaler scaler) => scaler.clamp(
        minScaleFactor: minTextScaleFactor,
        maxScaleFactor: maxTextScaleFactor,
      );

  static MediaQueryData clampMediaQuery(MediaQueryData data) => data.copyWith(
        textScaler: clampTextScaler(data.textScaler),
      );
}
