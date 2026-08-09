import 'package:flutter/material.dart';

/// 진에어 감성 대시보드 팔레트.
abstract final class DashboardPalette {
  static const Color softGray = Color(0xFFF3F5F8);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color lime = Color(0xFFB8D62E);
  static const Color limeBright = Color(0xFFD4E84A);
  static const Color teal = Color(0xFF1A9A9E);
  static const Color tealDeep = Color(0xFF0D7A7E);
  static const Color navy = Color(0xFF0F1B2D);
  static const Color textMuted = Color(0xFF8A94A6);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color shadow = Color(0x1A0F1B2D);

  /// 진에어 공식 브랜드 컬러 (RGB 기준).
  /// Green 190·214·0 · Purple 100·31·69 · Blue 0·159·218
  static const Color jinLime = Color(0xFFBED600);
  static const Color jinGreen = jinLime;
  static const Color jinLimeAlt = Color(0xFFD0E833);
  static const Color jinPurple = Color(0xFF641F45);
  static const Color jinBlue = Color(0xFF009FDA);
  /// @deprecated Use [jinPurple].
  static const Color jinMagenta = jinPurple;
  static const Color jinOlive = Color(0xFF4A5D23);
  static const Color jinSpecFill = Color(0xFFF8FAFC);
  static const Color jinBoardingNavy = Color(0xFF1E4A6B);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [lime, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient routeGradient = LinearGradient(
    colors: [limeBright, lime, teal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
