import 'package:flutter/material.dart';

import '../config/active5_layout.dart';

/// Galaxy Tab Active 5 기준 Material 3 테마.
/// 야외 가독성을 위해 기본 글자·터치 영역을 폰 UI보다 크게 설정한다.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF3E97C3);

  /// 본문·라벨 등 일반 텍스트
  static const String fontBody = 'SUIT';

  /// 제목·타이틀 등 강조 텍스트
  static const String fontDisplay = 'SUITE';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    const base = TextTheme(
      displayLarge: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
      displaySmall: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontFamily: fontBody, fontSize: 16),
      bodyMedium: TextStyle(fontFamily: fontBody, fontSize: 15),
      bodySmall: TextStyle(fontFamily: fontBody),
      labelLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontFamily: fontBody),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontBody,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F9FB),
      textTheme: base,
      primaryTextTheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        centerTitle: true,
        toolbarHeight: Active5Layout.appBarHeight,
        titleTextStyle: base.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            Active5Layout.minTouchTarget,
            Active5Layout.minTouchTarget,
          ),
          iconSize: 28,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, Active5Layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: base.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: base.bodyMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(fontFamily: fontBody, fontSize: 18),
      ),
    );
  }
}
