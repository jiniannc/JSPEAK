import 'package:flutter/material.dart';

/// 언어별 동적 컬러 팔레트 (ThemeExtension).
///
/// 배경(canvas)·카드는 언어 간 대비가 과하지 않도록 은은한 틴트만 둔다.
class LanguagePalette extends ThemeExtension<LanguagePalette> {
  final String language;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color surface;
  final Color accent;
  final Color tabSelected;
  final Color tabUnselected;
  final Color chipBackground;

  /// 화면 전체 배경 (subtle tint).
  final Color canvas;

  /// 리스트·진도 카드 면.
  final Color card;

  /// 카드 테두리.
  final Color cardBorder;

  /// 약한 채움(칩·세그먼트 배경).
  final Color softFill;

  /// Today's Pick 티켓 카드 메시 그라데이션 (시작·끝).
  final Color todayPickMeshStart;
  final Color todayPickMeshEnd;

  /// JSPEAK 로고 — 말풍선 왼쪽 + 3선 + 마침표.
  final Color brandLogoAccent;

  /// JSPEAK 워드마크 + 말풍선 오른쪽 (채도 낮은 네이비).
  final Color brandWordmark;

  const LanguagePalette({
    required this.language,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.surface,
    required this.accent,
    required this.tabSelected,
    required this.tabUnselected,
    required this.chipBackground,
    required this.canvas,
    required this.card,
    required this.cardBorder,
    required this.softFill,
    required this.todayPickMeshStart,
    required this.todayPickMeshEnd,
    required this.brandLogoAccent,
    required this.brandWordmark,
  });

  /// SVG FRAME_NAVY(#191F50) — JSPEAK·말풍선 오른쪽 공통, 채도 낮춘 슬레이트 네이비.
  static const brandWordmarkColor = Color(0xFF424962);

  /// Today's Pick 보딩패스 카드 배경 그라데이션.
  List<Color> todayPickMeshGradient() => [
        todayPickMeshStart.withValues(alpha: 0.90),
        todayPickMeshEnd.withValues(alpha: 0.58),
      ];

  /// EN — 슬레이트 블루, 차분한 항공 톤.
  static const english = LanguagePalette(
    language: 'English',
    primary: Color(0xFF4A6FA5),
    onPrimary: Colors.white,
    secondary: Color(0xFF6B7C93),
    surface: Color(0xFFF3F5F8),
    accent: Color(0xFF3D5A80),
    tabSelected: Color(0xFF4A6FA5),
    tabUnselected: Color(0xFF9AA8BC),
    chipBackground: Color(0xFFE4EAF2),
    canvas: Color(0xFFF1F4F8),
    card: Color(0xFFFBFCFE),
    cardBorder: Color(0xFFDCE3EC),
    softFill: Color(0xFFE8EEF5),
    todayPickMeshStart: Color(0xFFBAE6FD),
    todayPickMeshEnd: Color(0xFFE0F2FE),
    brandLogoAccent: Color(0xFF0755B8),
    brandWordmark: brandWordmarkColor,
  );

  /// JP — 뮤트 로즈 / 더스티 핑크 (사탕색 핑크 지양).
  static const japanese = LanguagePalette(
    language: 'Japanese',
    primary: Color(0xFFC4788A),
    onPrimary: Colors.white,
    secondary: Color(0xFFA88892),
    surface: Color(0xFFF6F1F3),
    accent: Color(0xFFB05F73),
    tabSelected: Color(0xFFC4788A),
    tabUnselected: Color(0xFFD4B8C0),
    chipBackground: Color(0xFFF3E6EA),
    canvas: Color(0xFFF4EFF1),
    card: Color(0xFFFFFBFC),
    cardBorder: Color(0xFFE6D8DD),
    softFill: Color(0xFFF0E4E8),
    todayPickMeshStart: Color(0xFFF5C6D0),
    todayPickMeshEnd: Color(0xFFFCE8EE),
    brandLogoAccent: Color(0xFFC4788A),
    brandWordmark: brandWordmarkColor,
  );

  /// CN — 소프트 플럼, 과하지 않은 바이올렛.
  static const chinese = LanguagePalette(
    language: 'Chinese',
    primary: Color(0xFF7A6499),
    onPrimary: Colors.white,
    secondary: Color(0xFF8E809E),
    surface: Color(0xFFF4F2F7),
    accent: Color(0xFF5E4A78),
    tabSelected: Color(0xFF7A6499),
    tabUnselected: Color(0xFFC2B6D0),
    chipBackground: Color(0xFFEAE4F1),
    canvas: Color(0xFFF2F0F6),
    card: Color(0xFFFCFBFE),
    cardBorder: Color(0xFFE0DAE8),
    softFill: Color(0xFFEBE6F2),
    todayPickMeshStart: Color(0xFFD4C8E8),
    todayPickMeshEnd: Color(0xFFEDE8F4),
    brandLogoAccent: Color(0xFF7A6499),
    brandWordmark: brandWordmarkColor,
  );

  static LanguagePalette forLanguage(String language) {
    return switch (language) {
      'Japanese' => japanese,
      'Chinese' => chinese,
      _ => english,
    };
  }

  ColorScheme toColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      tertiary: accent,
      surface: surface,
      surfaceContainerLowest: card,
      outline: cardBorder,
    );
  }

  /// 글래스 카드 면 — 흰 반투명 + 아주 약한 언어 틴트.
  Color glassFill({double alpha = 0.55, double tint = 0.035}) {
    return Color.lerp(Colors.white, primary, tint)!.withValues(alpha: alpha);
  }

  /// 글래스 테두리 — 하드 보더 대신 밝은 하이라이트.
  Color glassBorder({double alpha = 0.48}) =>
      Colors.white.withValues(alpha: alpha);

  /// 기내사전 메인 검색 — 해시태그 칩 배경.
  Color get searchTagBackground => todayPickMeshEnd;

  /// 기내사전 메인 검색 — 해시태그 칩 텍스트.
  Color get searchTagForeground => accent;

  /// 검색창 아이콘·링크·주사위 아이콘.
  Color get searchAccent => primary;

  /// 검색창 테두리.
  Color get searchFieldBorder => cardBorder;

  /// 주사위 버튼 배경.
  Color get diceButtonBackground => softFill;

  /// 말풍선 그라데이션 (위 → 아래).
  List<Color> get speechBubbleGradient => [
        Color.lerp(todayPickMeshStart, primary, 0.22)!,
        Color.lerp(primary, accent, 0.42)!,
      ];

  /// 즐겨찾기 섹션 배경.
  Color get favoritesSectionBackground => canvas;

  BoxDecoration glassCardDecoration({
    double radius = 16,
    double fillAlpha = 0.55,
    double tint = 0.035,
    double borderAlpha = 0.48,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: glassFill(alpha: fillAlpha, tint: tint),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder(alpha: borderAlpha)),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
    );
  }

  @override
  LanguagePalette copyWith({
    String? language,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? surface,
    Color? accent,
    Color? tabSelected,
    Color? tabUnselected,
    Color? chipBackground,
    Color? canvas,
    Color? card,
    Color? cardBorder,
    Color? softFill,
    Color? todayPickMeshStart,
    Color? todayPickMeshEnd,
    Color? brandLogoAccent,
    Color? brandWordmark,
  }) {
    return LanguagePalette(
      language: language ?? this.language,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      tabSelected: tabSelected ?? this.tabSelected,
      tabUnselected: tabUnselected ?? this.tabUnselected,
      chipBackground: chipBackground ?? this.chipBackground,
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      softFill: softFill ?? this.softFill,
      todayPickMeshStart: todayPickMeshStart ?? this.todayPickMeshStart,
      todayPickMeshEnd: todayPickMeshEnd ?? this.todayPickMeshEnd,
      brandLogoAccent: brandLogoAccent ?? this.brandLogoAccent,
      brandWordmark: brandWordmark ?? this.brandWordmark,
    );
  }

  @override
  LanguagePalette lerp(ThemeExtension<LanguagePalette>? other, double t) {
    if (other is! LanguagePalette) return this;
    return LanguagePalette(
      language: t < 0.5 ? language : other.language,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      tabSelected: Color.lerp(tabSelected, other.tabSelected, t)!,
      tabUnselected: Color.lerp(tabUnselected, other.tabUnselected, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      softFill: Color.lerp(softFill, other.softFill, t)!,
      todayPickMeshStart:
          Color.lerp(todayPickMeshStart, other.todayPickMeshStart, t)!,
      todayPickMeshEnd: Color.lerp(todayPickMeshEnd, other.todayPickMeshEnd, t)!,
      brandLogoAccent:
          Color.lerp(brandLogoAccent, other.brandLogoAccent, t)!,
      brandWordmark: Color.lerp(brandWordmark, other.brandWordmark, t)!,
    );
  }
}

extension LanguagePaletteContext on BuildContext {
  LanguagePalette? get languagePalette =>
      Theme.of(this).extension<LanguagePalette>();

  LanguagePalette get requireLanguagePalette =>
      languagePalette ?? LanguagePalette.english;
}
