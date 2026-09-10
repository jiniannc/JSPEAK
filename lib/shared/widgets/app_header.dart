import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/active5_layout.dart';
import '../../core/theme/language_palette.dart';
import 'compact_language_switcher.dart';
import 'jspeak_logo_color_mapper.dart';
import 'language_header_badge.dart';

/// 헤더 타이틀 전환 축 — 탭 전환(수평) vs 학습 상세(수직).
enum AppHeaderTransitionAxis { horizontal, vertical }

/// 메인 탭 · 학습 모드 공통 상단 헤더 (라인 아이콘 + 타이틀 + 언어 스위치).
/// 배경·구분선·섀도우 없이 화면 배경과 seamless하게 이어진다.
class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color titleDotColor;
  final Color? iconColor;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;
  final Color accent;
  final String? titleKey;
  final bool animateTitle;
  final AppHeaderTransitionAxis transitionAxis;
  final double trailingSlotWidth;
  final VoidCallback? onBrandTap;
  final VoidCallback? onBookmarkVaultTap;
  final String? homeRoute;
  final String? logoAsset;
  final bool usesGlobalTagline;

  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.titleDotColor,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.accent,
    this.iconColor,
    this.titleKey,
    this.animateTitle = true,
    this.transitionAxis = AppHeaderTransitionAxis.horizontal,
    this.trailingSlotWidth = 0,
    this.onBrandTap,
    this.onBookmarkVaultTap,
    this.homeRoute,
    this.logoAsset,
    this.usesGlobalTagline = false,
  });

  factory AppHeader.variant(
    AppHeaderVariant variant, {
    Key? key,
    required String selectedLanguage,
    required ValueChanged<String> onLanguageSelected,
    required Color accent,
    String? titleKey,
    bool animateTitle = true,
    AppHeaderTransitionAxis transitionAxis = AppHeaderTransitionAxis.horizontal,
    double trailingSlotWidth = 0,
    VoidCallback? onBrandTap,
    VoidCallback? onBookmarkVaultTap,
  }) {
    final style = variant.style;
    return AppHeader(
      key: key,
      title: style.title,
      subtitle: style.subtitle,
      icon: style.icon,
      titleDotColor: style.titleDotColor,
      iconColor: accent,
      selectedLanguage: selectedLanguage,
      onLanguageSelected: onLanguageSelected,
      accent: accent,
      titleKey: titleKey ?? variant.name,
      animateTitle: animateTitle,
      transitionAxis: transitionAxis,
      trailingSlotWidth: trailingSlotWidth,
      onBrandTap: onBrandTap,
      onBookmarkVaultTap: onBookmarkVaultTap,
      homeRoute: variant.homeRoute,
      logoAsset: style.logoAsset,
      usesGlobalTagline: style.usesGlobalTagline,
    );
  }

  /// 상단 여백 (SafeArea 아래) — 모든 탭 공통.
  static const topInset = 10.0;

  /// 타이틀·2줄 부제목까지 포함한 바 영역 고정 높이.
  static const barContentHeight = 60.0;

  /// 홈 로고 · 우측 trailing(언어·즐겨찾기) 공통 액션 밴드 높이.
  static const actionBandHeight = 58.0;

  /// 브랜드 락업 + 페이지 컨텍스트 바 영역 높이.
  static const homeBarContentHeight = 65.0;

  /// 로고·JSPEAK·섭텍스트 블록 상단 여백.
  static const homeBrandBlockTopPadding = 8.0;

  /// 로고+텍스트 락업 실제 높이 — trailing 세로 정렬 기준.
  static const homeBrandLockupHeight = 57.0;

  /// 별·언어 pill — JSPEAK 타이틀 행과 같은 높이 밴드.
  static const trailingBandHeight = 32.0;

  /// 로고 lift(-3)를 반영해 타이틀 행과 수평 정렬.
  static const trailingBandTop =
      topInset + homeBrandBlockTopPadding + homeBrandLogoLift;

  /// Shell 오버레이·탭 전환 슬롯 높이 (SafeArea 제외).
  static const slotHeight = topInset + barContentHeight;

  /// 브랜드 헤더 슬롯 높이 (SafeArea 제외).
  static const logoSlotHeight = topInset + homeBarContentHeight;

  /// Trailing(언어 스위치·즐겨찾기) — 모든 탭 동일 위치.
  static const trailingTop = topInset;
  static const trailingHeight = actionBandHeight;

  static const homeBrandTagline =
      'Global Communication Onboard Guide for Jinair Cabin Crew';

  static bool usesBrandHeader(int tabIndex) =>
      tabIndex >= 0 && tabIndex <= 3;

  static double slotHeightForTab(int tabIndex) =>
      usesBrandHeader(tabIndex) ? logoSlotHeight : slotHeight;

  /// 헤더 최소 높이 — [barContentHeight]와 동일 (하위 호환).
  static const minBarHeight = barContentHeight;

  static const trailingGap = 10.0;
  static const iconSpacing = 8.0;
  static const iconSize = 21.0;
  static const homeBrandLogoAsset = 'assets/images/JSPEAKLOGO.svg';
  static const homeBrandLogoAspect = 320 / 300;
  static const homeBrandIconHeight = 54.0;
  static const homeBrandLogoLift = -3.0;

  /// 로고는 고정, JSPEAK·섭텍스트만 살짝 아래로.
  static const homeBrandTextDrop = 2.5;

  /// 언어 전환 시 로고 바운스.
  static const brandLogoBounceDuration = Duration(milliseconds: 400);

  static const homeBrandIconGap = 6.0;
  static const homeBrandTextSize = 26.0;
  static const homeBrandBadgeGap = 4.0;
  static const homeBrandBadgeLift = 0.0;
  static const homeBrandTaglineGap = 0.0;
  static const homeBrandSectionGap = 2.0;
  /// 태그라인·섹션 라벨 공통 슬롯 — JSPEAK 세로 위치 고정.
  static const homeBrandContextSlotHeight = 24.0;
  static const homeBrandSectionTitleSize = 10.5;
  static const headerSwitchDuration = Duration(milliseconds: 420);
  static const switchInCurve = Curves.easeOutQuart;
  static const switchOutCurve = Curves.easeOutCubic;

  /// 헤더 아래 본문 시작 간격 — 콘텐츠 하단에 붙도록 최소화.
  static const bodyGap = 0.0;

  static const _titleColor = Color(0xFF0F172A);
  static const _subtitleColor = Color(0xFF64748B);
  static const _defaultIconColor = Color(0xFF334155);

  String get _contentKey => titleKey ?? title;

  void _handleBrandTap(BuildContext context) {
    if (onBrandTap != null) {
      onBrandTap!();
      return;
    }
    final route = homeRoute;
    if (route == null) return;
    final current = GoRouterState.of(context).uri.path;
    if (current != route) {
      context.go(route);
    }
  }

  Widget _buildTitleContent({
    required BuildContext context,
    required Color resolvedIconColor,
  }) {
    if (logoAsset != null) {
      return SizedBox(
        height: homeBarContentHeight,
        child: Padding(
          padding: const EdgeInsets.only(top: homeBrandBlockTopPadding),
          child: SizedBox(
            height: homeBrandLockupHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: _AppHeaderBrandLockup(
                logoAsset: logoAsset!,
                selectedLanguage: selectedLanguage,
                usesGlobalTagline: usesGlobalTagline,
                globalTagline: AppHeader.homeBrandTagline,
                sectionTitle: title,
                sectionAccent: titleDotColor,
                animateSection: animateTitle && !usesGlobalTagline,
                sectionKey: _contentKey,
                transitionAxis: transitionAxis,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: resolvedIconColor),
            const SizedBox(width: iconSpacing),
            Expanded(
              child: _TitleText(title: title, dotColor: titleDotColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: _SubtitleText(subtitle: subtitle),
        ),
      ],
    );
  }

  Widget _buildAnimatedTitleContent({
    required BuildContext context,
    required Color resolvedIconColor,
  }) {
    return AnimatedSwitcher(
      duration: headerSwitchDuration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return AppHeaderContentTransition(
          animation: animation,
          axis: transitionAxis,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(_contentKey),
        child: _buildTitleContent(
          context: context,
          resolvedIconColor: resolvedIconColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = Active5Layout.of(context).pagePadding.left;
    final resolvedIconColor = iconColor ?? _defaultIconColor;
    final canNavigate = onBrandTap != null || homeRoute != null;
    final usesLogo = logoAsset != null;
    final resolvedBarHeight =
        usesLogo ? homeBarContentHeight : barContentHeight;

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, topInset, inset, 0),
      child: SizedBox(
        height: resolvedBarHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canNavigate ? () => _handleBrandTap(context) : null,
                  borderRadius: BorderRadius.circular(12),
                  splashColor: accent.withValues(alpha: 0.08),
                  highlightColor: accent.withValues(alpha: 0.04),
                  child: animateTitle
                      ? _buildAnimatedTitleContent(
                          context: context,
                          resolvedIconColor: resolvedIconColor,
                        )
                      : _buildTitleContent(
                          context: context,
                          resolvedIconColor: resolvedIconColor,
                        ),
                ),
              ),
            ),
            SizedBox(width: trailingSlotWidth),
          ],
        ),
      ),
    );
  }
}

/// 헤더 우측 trailing — 탭 전환 애니메이션과 분리해 Shell에서 고정 렌더링.
class AppHeaderTrailing extends StatelessWidget {
  final Color accent;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;
  final bool showLanguageSwitcher;
  final VoidCallback? onBookmarkVaultTap;

  const AppHeaderTrailing({
    super.key,
    required this.accent,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.showLanguageSwitcher,
    this.onBookmarkVaultTap,
  });

  static double slotWidth({
    required bool showLanguageSwitcher,
    required bool showBookmark,
  }) {
    if (!showLanguageSwitcher && !showBookmark) return 0;
    var width = 0.0;
    if (showBookmark) {
      width += CompactLanguageDropdown.bookmarkButtonWidth;
      if (showLanguageSwitcher) {
        width += CompactLanguageDropdown.dividerSpacing * 2 +
            CompactLanguageDropdown.dividerWidth;
      }
    } else if (showLanguageSwitcher) {
      width += AppHeader.trailingGap;
    }
    if (showLanguageSwitcher) {
      width += CompactLanguageDropdown.outerWidth;
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    if (!showLanguageSwitcher && onBookmarkVaultTap == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: AppHeader.trailingBandHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBookmarkVaultTap != null) ...[
            _BookmarkVaultHeaderButton(
              accent: accent,
              onTap: onBookmarkVaultTap!,
            ),
            if (showLanguageSwitcher) ...[
              const SizedBox(width: CompactLanguageDropdown.dividerSpacing),
              Container(
                width: CompactLanguageDropdown.dividerWidth,
                height: 20,
                color: const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: CompactLanguageDropdown.dividerSpacing),
            ],
          ] else if (showLanguageSwitcher)
            const SizedBox(width: AppHeader.trailingGap),
          if (showLanguageSwitcher)
            CompactLanguageDropdown(
              selectedLanguage: selectedLanguage,
              onSelected: onLanguageSelected,
              accent: accent,
            ),
        ],
      ),
    );
  }
}

/// 타이틀·서브타이틀·아이콘 — 페이드 전환 (탭 전환과 겹치지 않도록 슬라이드 제거).
class AppHeaderContentTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const AppHeaderContentTransition({
    super.key,
    required this.child,
    required this.animation,
    AppHeaderTransitionAxis axis = AppHeaderTransitionAxis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppHeader.switchInCurve,
      reverseCurve: AppHeader.switchOutCurve,
    );

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        alignment: Alignment.topLeft,
        scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}

class _AppHeaderBrandLockup extends StatelessWidget {
  const _AppHeaderBrandLockup({
    required this.logoAsset,
    required this.selectedLanguage,
    required this.usesGlobalTagline,
    required this.globalTagline,
    required this.sectionTitle,
    required this.sectionAccent,
    required this.animateSection,
    required this.sectionKey,
    required this.transitionAxis,
  });

  final String logoAsset;
  final String selectedLanguage;
  final bool usesGlobalTagline;
  final String globalTagline;
  final String sectionTitle;
  final Color sectionAccent;
  final bool animateSection;
  final String sectionKey;
  final AppHeaderTransitionAxis transitionAxis;

  /// 로고·마침표는 3개 언어 팔레트만 사용 — 보간색마다 SVG를 재생성하지 않는다.
  LanguagePalette get _brandPalette =>
      LanguagePalette.forLanguage(selectedLanguage);

  Widget _buildContextLine() {
    if (usesGlobalTagline) {
      return _AppHeaderHomeTagline(text: globalTagline);
    }
    return _AppHeaderSectionLabel(
      title: sectionTitle,
      accent: sectionAccent,
    );
  }

  Widget _buildAnimatedContextLine() {
    final stackAlign =
        usesGlobalTagline ? Alignment.topLeft : Alignment.topCenter;
    return AnimatedSwitcher(
      duration: AppHeader.headerSwitchDuration,
      switchInCurve: AppHeader.switchInCurve,
      switchOutCurve: AppHeader.switchOutCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: stackAlign,
          clipBehavior: Clip.none,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return AppHeaderContentTransition(
          animation: animation,
          axis: transitionAxis,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(sectionKey),
        child: _buildContextLine(),
      ),
    );
  }

  Widget _buildContextSlot() {
    final child =
        animateSection ? _buildAnimatedContextLine() : _buildContextLine();
    return SizedBox(
      height: AppHeader.homeBrandContextSlotHeight,
      width: double.infinity,
      child: Align(
        alignment:
            usesGlobalTagline ? Alignment.topLeft : Alignment.topCenter,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 말풍선 오른쪽(FRAME_NAVY) · JSPEAK 텍스트 — 동일 hex 단일 소스.
    final brandWordmark = _brandPalette.brandWordmark;
    final brandLogoAccent = _brandPalette.brandLogoAccent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(0, AppHeader.homeBrandLogoLift),
          child: _BouncyBrandLogo(
            selectedLanguage: selectedLanguage,
            asset: logoAsset,
            height: AppHeader.homeBrandIconHeight,
            logoAccent: brandLogoAccent,
            wordmarkColor: brandWordmark,
          ),
        ),
        const SizedBox(width: AppHeader.homeBrandIconGap),
        Flexible(
          fit: FlexFit.loose,
          child: Padding(
            padding: const EdgeInsets.only(top: AppHeader.homeBrandTextDrop),
            child: Align(
              alignment: Alignment.topLeft,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AppHeaderHomeWordmark(
                      wordmarkColor: brandWordmark,
                      selectedLanguage: selectedLanguage,
                    ),
                    const SizedBox(height: AppHeader.homeBrandSectionGap),
                    _buildContextSlot(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppHeaderSectionLabel extends StatelessWidget {
  const _AppHeaderSectionLabel({
    required this.title,
    required this.accent,
  });

  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(
              fontFamily: 'SUIT',
              fontSize: AppHeader.homeBrandSectionTitleSize,
              fontWeight: FontWeight.w700,
              color: AppHeader._subtitleColor,
              letterSpacing: 0.12,
              height: 1.15,
            ),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(
              fontFamily: 'SUIT',
              fontSize: AppHeader.homeBrandSectionTitleSize,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncyBrandLogo extends StatefulWidget {
  const _BouncyBrandLogo({
    required this.selectedLanguage,
    required this.asset,
    required this.height,
    required this.logoAccent,
    required this.wordmarkColor,
  });

  final String selectedLanguage;
  final String asset;
  final double height;
  final Color logoAccent;
  final Color wordmarkColor;

  @override
  State<_BouncyBrandLogo> createState() => _BouncyBrandLogoState();
}

class _BouncyBrandLogoState extends State<_BouncyBrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: AppHeader.brandLogoBounceDuration,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.07)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.07, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 44,
      ),
    ]).animate(_bounce);
  }

  @override
  void didUpdateWidget(covariant _BouncyBrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLanguage != widget.selectedLanguage) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: _AppHeaderBrandIcon(
        asset: widget.asset,
        height: widget.height,
        logoAccent: widget.logoAccent,
        wordmarkColor: widget.wordmarkColor,
      ),
    );
  }
}

class _AppHeaderBrandIcon extends StatelessWidget {
  const _AppHeaderBrandIcon({
    required this.asset,
    required this.height,
    required this.logoAccent,
    required this.wordmarkColor,
  });

  final String asset;
  final double height;
  final Color logoAccent;
  final Color wordmarkColor;

  static const _cacheMultiplier = 2.0;
  static const _maxCacheSize = 180;

  bool get _isSvg => asset.toLowerCase().endsWith('.svg');

  double get _width =>
      height * (_isSvg ? AppHeader.homeBrandLogoAspect : 1.0);

  ImageProvider _provider(BuildContext context) {
    final cacheSize = (height * MediaQuery.devicePixelRatioOf(context) * _cacheMultiplier)
        .round()
        .clamp(1, _maxCacheSize);
    return ResizeImage(
      AssetImage(asset),
      height: cacheSize,
      width: cacheSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvg) {
      final colorMapper = JspeakLogoColorMapper(
        logoAccent: logoAccent,
        wordmarkColor: wordmarkColor,
      );
      return SvgPicture.asset(
        asset,
        height: height,
        width: _width,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        allowDrawingOutsideViewBox: true,
        clipBehavior: Clip.none,
        colorMapper: colorMapper,
      );
    }

    return Image(
      image: _provider(context),
      height: height,
      width: _width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      gaplessPlayback: true,
    );
  }
}

class _AppHeaderHomeWordmark extends StatelessWidget {
  const _AppHeaderHomeWordmark({
    required this.wordmarkColor,
    required this.selectedLanguage,
  });

  final Color wordmarkColor;
  final String selectedLanguage;

  @override
  Widget build(BuildContext context) {
    final wordStyle = TextStyle(
      fontFamily: 'SUIT',
      fontSize: AppHeader.homeBrandTextSize,
      fontWeight: FontWeight.w900,
      color: wordmarkColor,
      letterSpacing: -0.75,
      height: 1.0,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('JSPEAK', style: wordStyle),
        Padding(
          padding: const EdgeInsets.only(
            left: AppHeader.homeBrandBadgeGap,
            bottom: AppHeader.homeBrandBadgeLift,
          ),
          child: LanguageHeaderBadge(selectedLanguage: selectedLanguage),
        ),
      ],
    );
  }
}

class _AppHeaderHomeTagline extends StatelessWidget {
  const _AppHeaderHomeTagline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'SUIT',
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: AppHeader._subtitleColor,
        height: 1.15,
        letterSpacing: 0.05,
      ),
    );
  }
}

class _BookmarkVaultHeaderButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _BookmarkVaultHeaderButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CompactLanguageDropdown.bookmarkButtonWidth,
      height: CompactLanguageDropdown.pillHeight,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: accent,
          highlightColor: accent.withValues(alpha: 0.08),
          shape: const CircleBorder(),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          Icons.star_rounded,
          size: 20,
          color: accent.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  final String title;
  final Color dotColor;

  const _TitleText({super.key, required this.title, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppHeader._titleColor,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: dotColor,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtitleText extends StatelessWidget {
  final String subtitle;

  const _SubtitleText({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Text(
      subtitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppHeader._subtitleColor,
        height: 1.25,
      ),
    );
  }
}

enum AppHeaderVariant {
  home,
  learningHub,
  basicSentence,
  scenarioMode,
  wordSwipe,
  cabinDictionary,
  myPage;

  static AppHeaderVariant fromHubId(String id) {
    switch (id) {
      case 'hub':
        return AppHeaderVariant.learningHub;
      case 'basic_sentence':
        return AppHeaderVariant.basicSentence;
      case 'scenario':
        return AppHeaderVariant.scenarioMode;
      case 'word_swipe':
        return AppHeaderVariant.wordSwipe;
      default:
        return AppHeaderVariant.learningHub;
    }
  }

  String get homeRoute {
    switch (this) {
      case AppHeaderVariant.home:
        return '/';
      case AppHeaderVariant.learningHub:
        return '/scenarios';
      case AppHeaderVariant.basicSentence:
        return '/scenarios/sentences';
      case AppHeaderVariant.scenarioMode:
        return '/scenarios';
      case AppHeaderVariant.wordSwipe:
        return '/scenarios/swipe';
      case AppHeaderVariant.cabinDictionary:
        return '/dictionary';
      case AppHeaderVariant.myPage:
        return '/my';
    }
  }

  AppHeaderStyle get style {
    switch (this) {
      case AppHeaderVariant.home:
        return const AppHeaderStyle(
          title: 'JSPEAK',
          subtitle: AppHeader.homeBrandTagline,
          icon: Icons.flight_outlined,
          titleDotColor: Color(0xFF475569),
          logoAsset: AppHeader.homeBrandLogoAsset,
          usesGlobalTagline: true,
        );
      case AppHeaderVariant.learningHub:
        return const AppHeaderStyle(
          title: 'LEARNING HUB',
          subtitle: '',
          icon: Icons.school_outlined,
          titleDotColor: Color(0xFF38BDF8),
          logoAsset: AppHeader.homeBrandLogoAsset,
        );
      case AppHeaderVariant.basicSentence:
        return const AppHeaderStyle(
          title: 'BASIC SENTENCE',
          subtitle: '',
          icon: Icons.menu_book_outlined,
          titleDotColor: Color(0xFF38BDF8),
          logoAsset: AppHeader.homeBrandLogoAsset,
        );
      case AppHeaderVariant.scenarioMode:
        return const AppHeaderStyle(
          title: 'SCENARIO MODE',
          subtitle: '',
          icon: Icons.chat_bubble_outline_rounded,
          titleDotColor: Color(0xFF34D399),
          logoAsset: AppHeader.homeBrandLogoAsset,
        );
      case AppHeaderVariant.wordSwipe:
        return const AppHeaderStyle(
          title: 'WORD SWIPE',
          subtitle: '',
          icon: Icons.style_outlined,
          titleDotColor: Color(0xFFFB923C),
          logoAsset: AppHeader.homeBrandLogoAsset,
        );
      case AppHeaderVariant.cabinDictionary:
        return const AppHeaderStyle(
          title: 'CABIN DICTIONARY',
          subtitle: '',
          icon: Icons.menu_book_outlined,
          titleDotColor: Color(0xFF22D3EE),
          logoAsset: AppHeader.homeBrandLogoAsset,
        );
      case AppHeaderVariant.myPage:
        return const AppHeaderStyle(
          title: 'MY PAGE',
          subtitle: '',
          icon: Icons.person_outline_rounded,
          titleDotColor: Color(0xFF818CF8),
          logoAsset: AppHeader.homeBrandLogoAsset,
        );
    }
  }
}

class AppHeaderStyle {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color titleDotColor;
  final String? logoAsset;
  final bool usesGlobalTagline;

  const AppHeaderStyle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.titleDotColor,
    this.logoAsset,
    this.usesGlobalTagline = false,
  });
}
