import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/active5_layout.dart';
import 'compact_language_switcher.dart';

/// 헤더 타이틀 전환 축 — 탭 전환(수평) vs 학습 상세(수직).
enum AppHeaderTransitionAxis {
  horizontal,
  vertical,
}

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
  });

  factory AppHeader.variant(
    AppHeaderVariant variant, {
    Key? key,
    required String selectedLanguage,
    required ValueChanged<String> onLanguageSelected,
    required Color accent,
    String? titleKey,
    bool animateTitle = true,
    AppHeaderTransitionAxis transitionAxis =
        AppHeaderTransitionAxis.horizontal,
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
    );
  }

  /// 상단 여백 (SafeArea 아래).
  static const topInset = 14.0;

  /// 타이틀·2줄 부제목까지 포함한 바 영역 고정 높이.
  static const barContentHeight = 60.0;

  /// Shell 오버레이·탭 전환 슬롯 높이 (SafeArea 제외).
  static const slotHeight = topInset + barContentHeight;

  /// 헤더 최소 높이 — [barContentHeight]와 동일 (하위 호환).
  static const minBarHeight = barContentHeight;

  static const trailingGap = 10.0;
  static const iconSpacing = 8.0;
  static const iconSize = 21.0;
  static const headerSwitchDuration = Duration(milliseconds: 420);
  static const switchInCurve = Curves.easeOutQuart;
  static const switchOutCurve = Curves.easeOutCubic;

  /// 헤더 아래 본문 시작 간격.
  static const bodyGap = 16.0;

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

  Widget _buildTitleContent({required Color resolvedIconColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: resolvedIconColor,
            ),
            const SizedBox(width: iconSpacing),
            Expanded(
              child: _TitleText(
                title: title,
                dotColor: titleDotColor,
              ),
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

  Widget _buildAnimatedTitleContent({required Color resolvedIconColor}) {
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
        child: _buildTitleContent(resolvedIconColor: resolvedIconColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = Active5Layout.of(context).pagePadding.left;
    final resolvedIconColor = iconColor ?? _defaultIconColor;
    final canNavigate = onBrandTap != null || homeRoute != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, topInset, inset, 0),
      child: SizedBox(
        height: barContentHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canNavigate ? () => _handleBrandTap(context) : null,
                  borderRadius: BorderRadius.circular(12),
                  splashColor: accent.withValues(alpha: 0.08),
                  highlightColor: accent.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: animateTitle
                        ? _buildAnimatedTitleContent(
                            resolvedIconColor: resolvedIconColor,
                          )
                        : _buildTitleContent(
                            resolvedIconColor: resolvedIconColor,
                          ),
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
    var width = showBookmark ? 32.0 + 6.0 : AppHeader.trailingGap;
    if (showLanguageSwitcher) {
      width += CompactLanguageSwitcher.outerWidth;
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    if (!showLanguageSwitcher && onBookmarkVaultTap == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onBookmarkVaultTap != null) ...[
          _BookmarkVaultHeaderButton(
            accent: accent,
            onTap: onBookmarkVaultTap!,
          ),
          const SizedBox(width: 6),
        ] else if (showLanguageSwitcher)
          const SizedBox(width: AppHeader.trailingGap),
        if (showLanguageSwitcher)
          CompactLanguageSwitcher(
            selectedLanguage: selectedLanguage,
            onSelected: onLanguageSelected,
            accent: accent,
            seamless: true,
          ),
      ],
    );
  }
}

/// 탭 전환 완료 후 헤더 타이틀 위를 왼→오로 스weep하는 시머.
class AppHeaderShimmerOverlay extends StatelessWidget {
  final Animation<double> animation;

  const AppHeaderShimmerOverlay({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(animation.value);
        return ClipRect(
          child: Align(
            alignment: Alignment(-1.5 + 3.0 * t, 0),
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: FractionallySizedBox(
                widthFactor: 0.34,
                heightFactor: 2.8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.36, 0.5, 0.64, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

class _BookmarkVaultHeaderButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _BookmarkVaultHeaderButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: accent.withValues(alpha: 0.10),
        highlightColor: accent.withValues(alpha: 0.05),
        child: Ink(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.star_rounded,
            size: 17,
            color: accent.withValues(alpha: 0.92),
          ),
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
          subtitle: 'Global Communication Onboard',
          icon: Icons.flight_outlined,
          titleDotColor: Color(0xFF475569),
        );
      case AppHeaderVariant.learningHub:
        return const AppHeaderStyle(
          title: 'LEARNING HUB',
          subtitle: '다양한 학습 모드를 활용하여 기내 회화를 완성하세요',
          icon: Icons.school_outlined,
          titleDotColor: Color(0xFF38BDF8),
        );
      case AppHeaderVariant.basicSentence:
        return const AppHeaderStyle(
          title: 'BASIC SENTENCE',
          subtitle: '주제별 패턴 · 필수 문장 훈련',
          icon: Icons.menu_book_outlined,
          titleDotColor: Color(0xFF38BDF8),
        );
      case AppHeaderVariant.scenarioMode:
        return const AppHeaderStyle(
          title: 'SCENARIO MODE',
          subtitle: 'Interactive Scenario Simulation',
          icon: Icons.chat_bubble_outline_rounded,
          titleDotColor: Color(0xFF34D399),
        );
      case AppHeaderVariant.wordSwipe:
        return const AppHeaderStyle(
          title: 'WORD SWIPE',
          subtitle: '기내 필수 단어 3초 스와이프 훈련',
          icon: Icons.style_outlined,
          titleDotColor: Color(0xFFFB923C),
        );
      case AppHeaderVariant.cabinDictionary:
        return const AppHeaderStyle(
          title: 'CABIN DICTIONARY',
          subtitle: '상황별 필수 기내 표현을 검색해보세요',
          icon: Icons.menu_book_outlined,
          titleDotColor: Color(0xFF22D3EE),
        );
      case AppHeaderVariant.myPage:
        return const AppHeaderStyle(
          title: 'MY PAGE',
          subtitle: '프로필 설정 및 나의 학습 통계를 확인해보세요',
          icon: Icons.person_outline_rounded,
          titleDotColor: Color(0xFF818CF8),
        );
    }
  }
}

class AppHeaderStyle {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color titleDotColor;

  const AppHeaderStyle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.titleDotColor,
  });
}
