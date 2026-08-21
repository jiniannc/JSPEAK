import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dictionary_providers.dart';
import '../../app/learning_hub_language_provider.dart';
import '../../app/learning_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/theme/animated_language_scope.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/language_canvas_background.dart';
import '../dictionary/widgets/bookmark_vault_modal.dart';
import '../learning/learning_hub_shell.dart';

/// 홈 · 학습 · 기내사전 · 마이페이지 — 4개 탭 공통 헤더.
/// 탭 전환은 이 위젯 하나가 크로스페이드로 담당하고, 학습 탭
/// 내부의 서브 페이지 전환(기본 문장/시나리오/단어 스와이프)은 AppHeader
/// 자체의 AnimatedSwitcher(`animateTitle: true`)가 담당한다.
class MainShellTabHeader extends ConsumerStatefulWidget {
  final int tabIndex;

  const MainShellTabHeader({super.key, required this.tabIndex});

  static const kLearningTabIndex = 1;
  static const kMyPageTabIndex = 3;

  /// 헤더 오버레이 높이 — 탭 본문 top padding.
  static double reservedHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top +
        AppHeader.slotHeight +
        AppHeader.bodyGap;
  }

  @override
  ConsumerState<MainShellTabHeader> createState() => _MainShellTabHeaderState();
}

class _MainShellTabHeaderState extends ConsumerState<MainShellTabHeader>
    with TickerProviderStateMixin {
  static const _switchDuration = Duration(milliseconds: 480);
  static const _trailingFadeDuration = Duration(milliseconds: 420);

  late final AnimationController _controller;
  late final AnimationController _trailingFadeController;
  late final Animation<double> _trailingFade;
  int? _outgoingTabIndex;
  int _lastTabIndex = -1;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _switchDuration)
      ..value = 1;
    _trailingFadeController = AnimationController(
      vsync: this,
      duration: _trailingFadeDuration,
      value: widget.tabIndex == MainShellTabHeader.kMyPageTabIndex ? 0.0 : 1.0,
    );
    _trailingFade = CurvedAnimation(
      parent: _trailingFadeController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _animating) {
        setState(() {
          _animating = false;
          _outgoingTabIndex = null;
        });
      }
    });
    _lastTabIndex = widget.tabIndex;
  }

  @override
  void didUpdateWidget(covariant MainShellTabHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 4개 탭 모두 같은 위젯이 그리므로, 탭이 바뀌면(학습 탭 포함) 항상
    // 크로스페이드를 재생한다.
    if (widget.tabIndex != _lastTabIndex) {
      final previousTab = _lastTabIndex;
      _outgoingTabIndex = previousTab;
      _animating = true;

      if (_involvesMyPageTransition(previousTab, widget.tabIndex)) {
        if (widget.tabIndex == MainShellTabHeader.kMyPageTabIndex) {
          _trailingFadeController.reverse();
        } else {
          _trailingFadeController.forward(from: 0);
        }
      } else {
        _trailingFadeController.value =
            widget.tabIndex == MainShellTabHeader.kMyPageTabIndex ? 0.0 : 1.0;
      }

      // 첫 프레임부터 fadeT=0(나가는 헤더만 보임)으로 시작해야 새 타이틀이
      // 잠깐 노출된 뒤 슬라이드되는 깜빡임이 없다.
      _controller.stop();
      _controller.value = 0;

      // build/layout 단계 도중 컨트롤러를 즉시 구동하면 TickerMode 변경이
      // Riverpod의 provider refresh를 동기 트리거해 "setState during build"
      // 예외로 이어진다. value 리셋만 동기로 하고 재생은 다음 프레임으로 미룬다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.forward(from: 0);
      });
    }
    _lastTabIndex = widget.tabIndex;
  }

  @override
  void dispose() {
    _controller.dispose();
    _trailingFadeController.dispose();
    super.dispose();
  }

  bool _tabShowsLanguageSwitcher(int tabIndex) =>
      tabIndex != MainShellTabHeader.kMyPageTabIndex;

  double _trailingSlotWidthFor(int tabIndex) {
    return AppHeaderTrailing.slotWidth(
      showLanguageSwitcher: _tabShowsLanguageSwitcher(tabIndex),
      showBookmark: tabIndex != MainShellTabHeader.kMyPageTabIndex,
    );
  }

  bool _involvesMyPageTransition(int fromTab, int toTab) =>
      (fromTab == MainShellTabHeader.kMyPageTabIndex) !=
      (toTab == MainShellTabHeader.kMyPageTabIndex);

  int? _trailingTabIndexForDisplay() {
    if (widget.tabIndex != MainShellTabHeader.kMyPageTabIndex) {
      return widget.tabIndex;
    }

    // My Page — 페이드아웃 중에는 나가던 탭 trailing 유지(언마운트 깜빡임 방지)
    if (_trailingFadeController.isAnimating ||
        _trailingFadeController.value > 0) {
      final outgoing = _outgoingTabIndex;
      if (outgoing != null && outgoing != MainShellTabHeader.kMyPageTabIndex) {
        return outgoing;
      }
    }
    return null;
  }

  bool _shouldMountTrailingLayer() {
    final tab = _trailingTabIndexForDisplay();
    if (tab == null) return false;
    return _trailingFadeController.isAnimating ||
        _trailingFadeController.value > 0.001;
  }

  Widget? _buildFixedTrailing(BuildContext context, int tabIndex) {
    if (tabIndex == MainShellTabHeader.kMyPageTabIndex) {
      return null;
    }

    final showSwitcher = _tabShowsLanguageSwitcher(tabIndex);
    final language = tabIndex == 2
        ? ref.watch(selectedLanguageProvider)
        : ref.watch(learningHubLanguageProvider);

    return AnimatedLanguageScope(
      language: language,
      builder: (context, palette) => AppHeaderTrailing(
        accent: palette.primary,
        selectedLanguage: language,
        onLanguageSelected: tabIndex == 2
            ? (lang) => selectDictionaryLanguage(ref, lang)
            : (lang) => selectLearningLanguage(ref, lang),
        showLanguageSwitcher: showSwitcher,
        onBookmarkVaultTap: () => BookmarkVaultModal.show(context),
      ),
    );
  }

  Widget _buildHeaderFor(BuildContext context, int tabIndex) {
    final trailingSlotWidth = _trailingSlotWidthFor(tabIndex);

    if (tabIndex == MainShellTabHeader.kLearningTabIndex) {
      final language = ref.watch(learningHubLanguageProvider);
      final location = GoRouterState.of(context).uri.toString();
      final config = LearningHubShell.configForLocation(location);
      final isSubMode = LearningHubShell.isSubModeLocation(location);

      return AnimatedLanguageScope(
        language: language,
        builder: (context, palette) => AppHeader.variant(
          AppHeaderVariant.fromHubId(config.id),
          titleKey: config.id,
          selectedLanguage: language,
          onLanguageSelected: (lang) => selectLearningLanguage(ref, lang),
          accent: palette.primary,
          animateTitle: !_animating,
          transitionAxis: isSubMode
              ? AppHeaderTransitionAxis.vertical
              : AppHeaderTransitionAxis.horizontal,
          trailingSlotWidth: trailingSlotWidth,
        ),
      );
    }

    final variant = switch (tabIndex) {
      0 => AppHeaderVariant.home,
      2 => AppHeaderVariant.cabinDictionary,
      3 => AppHeaderVariant.myPage,
      _ => AppHeaderVariant.home,
    };

    final language = tabIndex == 2
        ? ref.watch(selectedLanguageProvider)
        : ref.watch(learningHubLanguageProvider);

    return AnimatedLanguageScope(
      language: language,
      builder: (context, palette) => AppHeader.variant(
        variant,
        selectedLanguage: language,
        onLanguageSelected: tabIndex == 2
            ? (lang) => selectDictionaryLanguage(ref, lang)
            : (lang) => selectLearningLanguage(ref, lang),
        accent: palette.primary,
        animateTitle: false,
        trailingSlotWidth: trailingSlotWidth,
        onBrandTap: tabIndex == 2
            ? () {
                resetDictionaryHome(ref);
                final path = GoRouterState.of(context).uri.path;
                if (path != '/dictionary') {
                  context.go('/dictionary');
                }
              }
            : null,
      ),
    );
  }

  Widget _wrapTransitionLayer({
    required double opacity,
    required Widget child,
    double scale = 1.0,
  }) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scale: scale,
        child: child,
      ),
    );
  }

  ({double incoming, double outgoing, double incomingScale, double outgoingScale})
      _crossfadeProgress(double t) {
    // 나가는 타이틀은 전반부에 빠르게 퇴장, 들어오는 타이틀은 약간 늦게 등장해
    // 겹침 구간을 짧게 유지한다.
    final outgoingT = Curves.easeOutCubic.transform(_remap(t, 0.0, 0.45));
    final incomingT = Curves.easeOutQuart.transform(_remap(t, 0.14, 0.96));
    return (
      incoming: incomingT,
      outgoing: 1 - outgoingT,
      incomingScale: 0.93 + (0.07 * incomingT),
      outgoingScale: 1.0 - (0.05 * outgoingT),
    );
  }

  static double _remap(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  Widget _buildHeaderStack(
    BuildContext context,
    double inset, {
    required double progressT,
  }) {
    Widget buildTitleHeader(int tabIndex) {
      return KeyedSubtree(
        key: ValueKey<int>(tabIndex),
        child: _buildHeaderFor(context, tabIndex),
      );
    }

    Widget buildTitleLayers(double progressT) {
      if (!_animating) {
        return Align(
          alignment: Alignment.topLeft,
          child: buildTitleHeader(widget.tabIndex),
        );
      }

      final crossfade = _crossfadeProgress(progressT);
      final outgoingTab = _outgoingTabIndex;
      final outgoing =
          outgoingTab == null ? null : buildTitleHeader(outgoingTab);
      final current = buildTitleHeader(widget.tabIndex);

      return ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (outgoing != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _wrapTransitionLayer(
                  opacity: crossfade.outgoing,
                  scale: crossfade.outgoingScale,
                  child: outgoing,
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _wrapTransitionLayer(
                opacity: crossfade.incoming,
                scale: crossfade.incomingScale,
                child: current,
              ),
            ),
          ],
        ),
      );
    }

    final trailingTab = _trailingTabIndexForDisplay();
    final mountTrailing = _shouldMountTrailingLayer();

    // 타이틀만 크로스페이드하고, 언어 스위치·즐겨찾기는 Stack 최상단에 고정.
    return SizedBox(
      height: AppHeader.slotHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          buildTitleLayers(progressT),
          if (mountTrailing && trailingTab != null)
            Positioned(
              top: AppHeader.topInset,
              right: inset,
              height: AppHeader.barContentHeight,
              child: Align(
                alignment: Alignment.topRight,
                child: FadeTransition(
                  opacity: _trailingFade,
                  child: IgnorePointer(
                    ignoring: _trailingFadeController.value < 0.05,
                    child: _buildFixedTrailing(context, trailingTab),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = Active5Layout.of(context).pagePadding.left;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _controller,
        _trailingFadeController,
      ]),
      builder: (context, _) {
        final progressT = _animating ? _controller.value : 1.0;
        return _buildHeaderStack(context, inset, progressT: progressT);
      },
    );
  }
}

/// Shell 헤더 아래 본문 — 헤더 오버레이만큼 top padding.
class MainShellTabBody extends StatelessWidget {
  final Widget child;

  const MainShellTabBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MainShellTabHeader.reservedHeight(context),
      ),
      child: child,
    );
  }
}

/// MainShell 상단 헤더 오버레이 — 4개 탭 공통.
class MainShellHeaderOverlay extends StatelessWidget {
  final int tabIndex;

  const MainShellHeaderOverlay({super.key, required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: MainShellTabHeader(tabIndex: tabIndex),
    );
  }
}

/// Shell 전체 배경 — 헤더·본문 이음매 없이 4개 탭 모두 하나의 그라데이션으로
/// 이어진다.
class MainShellBackground extends ConsumerWidget {
  final int tabIndex;

  const MainShellBackground({super.key, required this.tabIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = tabIndex == 2
        ? ref.watch(selectedLanguageProvider)
        : ref.watch(learningHubLanguageProvider);

    return AnimatedLanguageScope(
      language: language,
      builder: (context, palette) => LanguageCanvasBackground(
        palette: palette,
        child: const SizedBox.expand(),
      ),
    );
  }
}
