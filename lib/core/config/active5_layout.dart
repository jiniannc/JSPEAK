import 'package:flutter/material.dart';

/// Galaxy Tab Active 5 (SM-X306, 8.0", WUXGA 1920×1200, 16:10) 레이아웃 기준.
///
/// Flutter 논리 해상도(밀도 ≈ 2.0 기준):
/// - 세로: 600 × 960 dp
/// - 가로: 960 × 600 dp
///
/// 기내·야외에서 한 손/두 손 조작과 장갑 착용을 고려해
/// 터치 영역과 글자 크기를 폰보다 크게 잡는다.
class Active5Layout {
  Active5Layout._();

  static const String deviceName = 'Galaxy Tab Active 5';

  /// Chrome 등에서 Active 5 뷰포트로 미리보기할 때 권장 크기 (가로).
  static const Size previewLandscape = Size(960, 600);

  /// 세로 모드 권장 뷰포트.
  static const Size previewPortrait = Size(600, 960);

  static const double logicalWidthPortrait = 600;
  static const double logicalWidthLandscape = 960;

  static const double pagePaddingH = 20;
  static const double pagePaddingV = 16;
  static const double minTouchTarget = 52;
  static const double appBarHeight = 64;

  static Active5Metrics of(BuildContext context) => Active5Metrics(context);
}

/// [BuildContext]에서 읽은 Active 5 맞춤 치수.
class Active5Metrics {
  Active5Metrics(BuildContext context)
      : size = MediaQuery.sizeOf(context),
        padding = MediaQuery.paddingOf(context),
        isLandscape =
            MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

  final Size size;
  final EdgeInsets padding;
  final bool isLandscape;

  double get contentWidth =>
      size.width - Active5Layout.pagePaddingH * 2;

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
        Active5Layout.pagePaddingH,
        Active5Layout.pagePaddingV,
        Active5Layout.pagePaddingH,
        Active5Layout.pagePaddingV + padding.bottom,
      );

  /// 카테고리 그리드 열 수 (Active 5: 세로 3열, 가로 4열).
  int get categoryColumns => isLandscape ? 4 : 3;

  /// 카테고리 타일 한 변 길이.
  double get categoryTileExtent => isLandscape ? 168 : 176;

  /// 언어 선택 타일 최소 높이.
  double get languageTileMinHeight => isLandscape ? 140 : 96;

  /// 문장 카드 외국어 글자 크기.
  double get sentenceFontSize => isLandscape ? 22 : 20;

  double get pronunciationFontSize => isLandscape ? 17 : 16;

  double get koreanFontSize => isLandscape ? 16 : 15;

  double get languageEmojiSize => isLandscape ? 52 : 44;

  double get languageTitleSize => isLandscape ? 22 : 20;

  double get playButtonSize => 52;
}
