import 'package:flutter/material.dart';

/// Galaxy Tab Active 5 (SM-X306, 8.0", WUXGA 1920×1200, 16:10) 레이아웃 기준.
///
/// **배포 전략:** 기본 타깃은 Active 5 한 기기(논리 600×960 / 960×600)입니다.
/// `DeviceScaffold`·`Active5Metrics`가 이 치수를 기준으로 여백·열 수·글자 크기를 맞춥니다.
///
/// 웹 GitHub Pages 데모는 `Active5WebViewport` + `JSPEAK_WEB_DEMO`로 동일 비율을 흉내 냅니다.
///
/// 폰·다른 태블릿까지 넓힐 때는 [Active5FormFactor] 임계값과 [Active5Metrics] getter만
/// 조정하면 됩니다(화면마다 MediaQuery 분기를 늘리지 않음).
class Active5Layout {
  Active5Layout._();

  static const String deviceName = 'Galaxy Tab Active 5';

  /// Chrome 등에서 Active 5 뷰포트로 미리보기할 때 권장 크기 (가로).
  static const Size previewLandscape = Size(960, 600);

  /// 세로 모드 권장 뷰포트.
  static const Size previewPortrait = Size(600, 960);

  static const double logicalWidthPortrait = 600;
  static const double logicalWidthLandscape = 960;

  /// [Active5FormFactor.phone] — 이보다 좁으면 컴팩트 레이아웃.
  static const double phoneMaxWidth = 599;

  /// [Active5FormFactor.tabletLandscape] — 가로 폭이 이 값 이상이면 960dp 기준.
  static const double tabletLandscapeMinWidth = 840;

  static const double pagePaddingH = 20;
  static const double pagePaddingV = 16;
  static const double minTouchTarget = 52;
  static const double appBarHeight = 64;

  static Active5Metrics of(BuildContext context) => Active5Metrics(context);
}

/// 화면 폭·방향에 따른 레이아웃 프로필 (브레이크포인트).
enum Active5FormFactor {
  /// 좁은 화면(일반 스마트폰) — 열 수·글자 축소, maxWidth는 실제 폭.
  phone,

  /// Active 5 세로 등 — 논리 폭 600dp.
  tabletPortrait,

  /// Active 5 가로 등 — 논리 폭 960dp.
  tabletLandscape;

  static Active5FormFactor fromSize(Size size) {
    final landscape = size.width > size.height;
    if (landscape) {
      if (size.width >= Active5Layout.tabletLandscapeMinWidth) {
        return Active5FormFactor.tabletLandscape;
      }
      if (size.width <= Active5Layout.phoneMaxWidth) {
        return Active5FormFactor.phone;
      }
      return Active5FormFactor.tabletPortrait;
    }
    if (size.width <= Active5Layout.phoneMaxWidth) {
      return Active5FormFactor.phone;
    }
    if (size.width >= Active5Layout.logicalWidthPortrait) {
      return Active5FormFactor.tabletPortrait;
    }
    return Active5FormFactor.phone;
  }

  bool get isLandscape => this == Active5FormFactor.tabletLandscape;
}

/// [BuildContext]에서 읽은 Active 5 맞춤 치수.
class Active5Metrics {
  Active5Metrics(BuildContext context)
      : size = MediaQuery.sizeOf(context),
        padding = MediaQuery.paddingOf(context),
        formFactor = Active5FormFactor.fromSize(MediaQuery.sizeOf(context));

  final Size size;
  final EdgeInsets padding;
  final Active5FormFactor formFactor;

  /// 가로/세로 (Active 5 가로 모드).
  bool get isLandscape => formFactor == Active5FormFactor.tabletLandscape;

  /// [DeviceScaffold] 등에서 본문 최대 폭.
  double get maxContentWidth => switch (formFactor) {
        Active5FormFactor.tabletLandscape =>
          Active5Layout.logicalWidthLandscape,
        Active5FormFactor.tabletPortrait => Active5Layout.logicalWidthPortrait,
        Active5FormFactor.phone => size.width,
      };

  double get contentWidth => maxContentWidth - Active5Layout.pagePaddingH * 2;

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
        Active5Layout.pagePaddingH,
        Active5Layout.pagePaddingV,
        Active5Layout.pagePaddingH,
        Active5Layout.pagePaddingV + padding.bottom,
      );

  /// 카테고리 그리드 열 수.
  int get categoryColumns => switch (formFactor) {
        Active5FormFactor.tabletLandscape => 4,
        Active5FormFactor.tabletPortrait => 3,
        Active5FormFactor.phone => 2,
      };

  /// 카테고리 타일 한 변 길이.
  double get categoryTileExtent => switch (formFactor) {
        Active5FormFactor.tabletLandscape => 168,
        Active5FormFactor.tabletPortrait => 176,
        Active5FormFactor.phone => 148,
      };

  /// 언어 선택 타일 최소 높이.
  double get languageTileMinHeight => switch (formFactor) {
        Active5FormFactor.tabletLandscape => 140,
        Active5FormFactor.tabletPortrait => 96,
        Active5FormFactor.phone => 88,
      };

  /// 문장 카드 외국어 글자 크기.
  double get sentenceFontSize => switch (formFactor) {
        Active5FormFactor.tabletLandscape => 22,
        Active5FormFactor.tabletPortrait => 20,
        Active5FormFactor.phone => 18,
      };

  double get pronunciationFontSize => switch (formFactor) {
        Active5FormFactor.tabletLandscape => 17,
        Active5FormFactor.tabletPortrait => 16,
        Active5FormFactor.phone => 15,
      };

  double get koreanFontSize => switch (formFactor) {
        Active5FormFactor.tabletLandscape => 16,
        Active5FormFactor.tabletPortrait => 15,
        Active5FormFactor.phone => 14,
      };

  double get languageEmojiSize => switch (formFactor) {
        Active5FormFactor.tabletLandscape => 52,
        Active5FormFactor.tabletPortrait => 44,
        Active5FormFactor.phone => 40,
      };

  double get languageTitleSize => switch (formFactor) {
        Active5FormFactor.tabletLandscape => 22,
        Active5FormFactor.tabletPortrait => 20,
        Active5FormFactor.phone => 18,
      };

  double get playButtonSize => 52;
}
