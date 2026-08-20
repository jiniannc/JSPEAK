import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/learning_hub_language_provider.dart';
import '../../app/providers.dart';
import '../../app/scenario_providers.dart';
import '../../app/sentence_progress_providers.dart';
import '../../app/swipe_progress_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/theme/language_palette.dart';
import '../../core/utils/learning_hub_icon.dart';
import '../../data/models/content_bundle.dart';
import '../../data/models/learning_hub_chapter.dart';
import '../../data/repositories/sentence_progress_repository.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../shell/floating_island_nav_bar.dart';
import '../shell/main_shell_tab_header.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/cascade_entrance.dart';
import '../../shared/widgets/flight_progress_bar.dart';
import 'widgets/learning_hub_chapter_card.dart';

/// 학습 탭 메인 — 비행 단계별 허브 카드에서 3모드로 진입.
class LearningHomeScreen extends ConsumerStatefulWidget {
  const LearningHomeScreen({super.key});

  @override
  ConsumerState<LearningHomeScreen> createState() =>
      _LearningHomeScreenState();
}

class _LearningHomeScreenState extends ConsumerState<LearningHomeScreen> {
  int? _expandedChapterNo;
  bool _initialFocusPending = true;
  bool _initialFocusQueued = false;
  bool _suppressScrollExpand = false;
  bool _hubListVisible = true;

  late ScrollController _scrollController;
  late String _displayLanguage;
  final GlobalKey _viewportKey = GlobalKey();
  final Map<int, double> _chapterHeights = {};
  int _listEpoch = 0;
  String? _precachedImagesLanguage;
  bool _compactScrollMode = false;
  double _scrollDragStartOffset = 0;
  bool _isUserDragScroll = false;
  double _scrollPeakVelocity = 0;
  double _scrollSampleOffset = 0;
  DateTime? _scrollSampleTime;
  List<int> _orderedChapterNos = const [];
  Map<int, LearningHubChapter> _chaptersByNo = const {};
  int _chapterSnapToken = 0;
  int? _outgoingExpandedChapterNo;
  int? _activeCenterScrollChapter;
  int _scrollGeneration = 0;
  Object? _scrollFinalizeToken;

  /// true인 동안(=우리가 직접 애니메이션을 걸지 않고 레이아웃 안정만
  /// 기다리는 구간)에 스크롤 알림이 도착하면, 그건 우리가 만든 게 아니라
  /// 사용자가 마우스 휠/드래그로 직접 스크롤을 시도한 것이다. 이때는
  /// 최종 보정으로 사용자의 위치를 강제로 되돌리지 않아야 한다.
  bool _awaitingFinalize = false;
  bool _userInterruptedFinalize = false;

  /// 전환(펼침/접힘) 도중에만 임시로 늘어나는 하단 여백.
  /// 접히는 카드가 펼쳐지는 카드보다 먼저 다 접히면(680ms vs 420ms 속도
  /// 차이) maxScrollExtent가 순간적으로 목표치보다 작아지고,
  /// ClampingScrollPhysics가 애니메이션 도중 스크롤 위치를 그 낮아진
  /// max로 강제로 깎아버린다 — 그 결과 애니메이션이 끝난 뒤 실제 위치와
  /// 목표가 크게 벌어져 있어서 "점프"가 발생한다. 전환 중 여유 공간을
  /// 미리 확보해 이 클램핑 자체가 일어나지 않게 막는다.
  double _transientBottomSlack = 0;

  /// 하단 N개 챕터는 포커스 정렬 대신 스크롤 가능한 최상단(max)에 고정.
  static const _nearBottomChapterCount = 3;

  /// 플로팅 프로그레스 헤더 높이 — 트랙·카운트 텍스트 고정 레이아웃.
  double get _floatingHeaderHeight =>
      HubGrooveProgressTrack.totalBlockHeight + 4;

  /// 스크롤 다운 시 플로팅 프로그레스 헤더가 완전히 사라지기까지의 거리.
  static const _floatingHeaderFadeDistance = 44.0;

  static const _longDragThresholdPx = 96.0;
  static const _shortSwipeVelocityPx = 220.0;
  /// 실제로 손가락/마우스가 이 정도는 움직여야 flick으로 인정한다.
  /// 속도 계산이 잡음으로 튀는 극단적인 경우에도, 거의 움직이지 않은
  /// "누르고만 있던" 제스처가 챕터 스냅으로 오판되지 않도록 하는
  /// 마지막 안전장치.
  static const _minFlickDistancePx = 12.0;
  /// 헤더·하단 네비를 고려한 포커스 위치 (가용 영역 상단 기준).
  static const _focusBandFraction = 0.40;

  /// 헤더 바로 아래 — 가용 영역(band)의 시작 Y.
  double _viewportBandTop(BuildContext context) =>
      MainShellTabHeader.reservedHeight(context);

  /// 화면 기준 포커스 Y — ListView 중앙(50%)보다 위쪽.
  double _viewportFocusY(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bandTop = _viewportBandTop(context);
    final bandBottom =
        screenHeight - FloatingIslandNavBar.reservedHeight(context) * 0.35;
    return bandTop + (bandBottom - bandTop) * _focusBandFraction;
  }

  /// 리스트 하단 패딩 — 플로팅 네비 위에 마지막 카드가 닿을 정도.
  double _listBottomPadding(BuildContext context) =>
      FloatingIslandNavBar.scrollBottomClearance + 12 + _transientBottomSlack;

  /// 맨 위(offset≈0)에서는 1, 아래로 스크롤할수록 0에 가깝게 — easeOut으로
  /// 자연스럽게 페이드아웃.
  double _floatingHeaderOpacityFor(double scrollOffset) {
    if (scrollOffset <= 0) return 1;
    final t =
        (scrollOffset / _floatingHeaderFadeDistance).clamp(0.0, 1.0);
    return Curves.easeOut.transform(1.0 - t);
  }

  ScrollPosition? get _scrollPositionOrNull {
    if (!_scrollController.hasClients) return null;
    if (_scrollController.positions.length != 1) return null;
    return _scrollController.position;
  }

  double _safeScrollOffset() => _scrollPositionOrNull?.pixels ?? 0.0;

  double get _listPaddingTop =>
      _floatingHeaderHeight + 10 - AppHeader.bodyGap;

  void _onChapterHeightChanged(int chapterNo, double height) {
    if (height <= 0) return;
    final prev = _chapterHeights[chapterNo];
    if (prev != null && (prev - height).abs() < 0.5) return;
    _chapterHeights[chapterNo] = height;
  }

  double _heightForChapter(int chapterNo) {
    final measured = _chapterHeights[chapterNo];
    if (measured != null && measured > 0) return measured;

    final index = _orderedChapterNos.indexOf(chapterNo);
    final isLast =
        index >= 0 && index == _orderedChapterNos.length - 1;
    final isExpanded = chapterNo == _expandedChapterNo ||
        chapterNo == _outgoingExpandedChapterNo;
    if (isExpanded) {
      return _estimateExpandedHeightFor(chapterNo, context);
    }
    return LearningHubChapterCard.compactBlockHeight(isLast: isLast);
  }

  double _cardTopForChapter(int chapterNo) {
    final position = _scrollPositionOrNull;
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (position == null || viewportBox == null || !viewportBox.hasSize) {
      return 0;
    }

    final listTop = viewportBox.localToGlobal(Offset.zero).dy;
    final index = _orderedChapterNos.indexOf(chapterNo);
    if (index < 0) return listTop + _listPaddingTop - position.pixels;

    var offset = _listPaddingTop;
    for (var i = 0; i < index; i++) {
      offset += _heightForChapter(_orderedChapterNos[i]);
    }
    return listTop + offset - position.pixels;
  }

  /// 화면 맨 위에 고정으로 얹는 스크림의 높이·최대 알파.
  /// 카드나 리스트에는 손대지 않고, 화면 상단에만 배경과 같은 톤의
  /// 그라데이션을 깔아서 그 밑을 스크롤해 지나가는 카드가 "뚝 끊기지"
  /// 않고 배경 쪽으로 자연스럽게 녹아드는 것처럼 보이게 한다.
  static const _topScrimHeight = 64.0;
  static const _topScrimMaxAlpha = 0.94;

  /// 화면 배경(LanguageCanvasBackground)의 좌상단 색과 정확히 맞춰
  /// 스크림이 "이질적인 하얀 오버레이"가 아니라 배경 자체의 연장처럼
  /// 보이게 한다.
  Color _topScrimColor(BuildContext context) {
    final palette = context.requireLanguagePalette;
    return Color.lerp(palette.canvas, Colors.white, 0.35)!;
  }

  /// 다단(multi-stop) 이즈 커브로 떨어지는 스크림 그라데이션.
  /// 2-stop 선형 그라데이션은 눈에 "경계선"처럼 보이기 쉬워서, 위쪽은
  /// 배경과 거의 동일하게 진하게 유지하고 아래로 갈수록 빠르게 옅어지는
  /// 5단 easeIn 커브로 대비감 있게, 그러나 자연스럽게 사라지도록 한다.
  LinearGradient _topScrimGradient(BuildContext context) {
    final color = _topScrimColor(context);
    const stops = [0.0, 0.30, 0.55, 0.78, 1.0];
    const easedAlphaFractions = [1.0, 0.86, 0.56, 0.24, 0.0];
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: stops,
      colors: [
        for (final fraction in easedAlphaFractions)
          color.withValues(alpha: _topScrimMaxAlpha * fraction),
      ],
    );
  }

  /// 챕터[chapterNo]가 펼쳐질 때 실제로 "자라나는" 높이만큼 임시 여유
  /// 공간을 계산한다. 이 값만큼 하단 패딩을 늘려두면, 접히는 카드가
  /// 먼저 다 접혀서 max가 순간적으로 줄어도 목표 스크롤 위치가
  /// 여전히 max 이하로 유지되어 애니메이션 도중 클램핑이 발생하지 않는다.
  double _computeTransientSlack(int chapterNo) {
    final index = _orderedChapterNos.indexOf(chapterNo);
    final isLast = index >= 0 && index == _orderedChapterNos.length - 1;
    final compact = LearningHubChapterCard.compactBlockHeight(isLast: isLast);
    final start = _measuredCardHeight(chapterNo) ?? compact;
    final expanded = _estimateExpandedHeightFor(chapterNo, context);
    final growth = expanded - start;
    if (growth <= 0) return 0;
    return growth + 32;
  }

  void _clampScrollToMax() {
    final position = _scrollPositionOrNull;
    if (position == null) return;
    if (position.pixels > position.maxScrollExtent + 0.5) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  /// 목표 스크롤 위치를 실제 maxScrollExtent에 정확히 맞춘다(양방향 보정).
  /// 추정치 오차를 애니메이션 종료 후 한 번만 조용히 바로잡기 위한 용도.
  void _snapToMaxScrollExtent() {
    final position = _scrollPositionOrNull;
    if (position == null) return;
    _softCorrectScroll(position, position.maxScrollExtent);
  }

  /// 예측이 실제와 조금 어긋났을 때의 최종 보정.
  /// 오차가 작으면(24px 이하) 즉시 jumpTo — 어차피 안 보임.
  /// 오차가 크면 순간이동(jumpTo) 대신 짧고 부드러운 애니메이션으로
  /// 보정해, 예측이 빗나가도 "점프"가 아니라 매끄러운 추가 스크롤처럼
  /// 보이게 한다.
  static const _softCorrectThreshold = 24.0;
  static const _softCorrectDuration = Duration(milliseconds: 220);

  void _softCorrectScroll(ScrollPosition position, double target) {
    final diff = (target - position.pixels).abs();
    if (diff <= 0.5) return;
    if (diff <= _softCorrectThreshold) {
      position.jumpTo(target);
    } else {
      position.animateTo(
        target,
        duration: _softCorrectDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _isNearBottomChapter(int chapterNo) {
    final index = _orderedChapterNos.indexOf(chapterNo);
    if (index < 0) return false;
    return index >= _orderedChapterNos.length - _nearBottomChapterCount;
  }

  void _stopScrollAnimation() {
    final position = _scrollPositionOrNull;
    if (position == null) return;
    if (position.isScrollingNotifier.value) {
      position.jumpTo(position.pixels);
    }
  }

  /// 챕터 카드의 "지금 이 순간" 실측 높이. 이전 전환이 끝나지 않은 채
  /// 중간에 끼어들어도(빠른 연속 탭) 항상 실제 현재 값을 반영한다.
  double? _measuredCardHeight(int chapterNo) {
    final height = _chapterHeights[chapterNo];
    if (height == null || height <= 0) return null;
    return height;
  }

  /// 챕터 펼침·접힘으로 늘어나거나 줄어드는 콘텐츠 총 높이.
  /// "완전히 펼쳐진/접힌 상태"라고 가정하지 않고, 두 카드의 실제 현재
  /// 높이를 측정해 계산한다 — 이전 전환이 중간에 끊긴 채로 새 탭이
  /// 들어와도(빠른 연속 탭) 정확한 시작점을 알 수 있어 튕기지 않는다.
  double _predictedContentHeightDelta({
    required int chapterNo,
    int? outgoingChapterNo,
  }) {
    final targetIndex = _orderedChapterNos.indexOf(chapterNo);
    final targetIsLast =
        targetIndex >= 0 && targetIndex == _orderedChapterNos.length - 1;
    final targetCompact =
        LearningHubChapterCard.compactBlockHeight(isLast: targetIsLast);
    final targetStart = _measuredCardHeight(chapterNo) ?? targetCompact;
    final targetExpanded = _estimateExpandedHeightFor(chapterNo, context);

    var delta = targetExpanded - targetStart;

    if (outgoingChapterNo != null && outgoingChapterNo != chapterNo) {
      final outgoingIndex = _orderedChapterNos.indexOf(outgoingChapterNo);
      if (outgoingIndex >= 0) {
        final outgoingIsLast =
            outgoingIndex == _orderedChapterNos.length - 1;
        final outgoingCompact = LearningHubChapterCard.compactBlockHeight(
          isLast: outgoingIsLast,
        );
        final outgoingExpanded =
            _estimateExpandedHeightFor(outgoingChapterNo, context);
        final outgoingStart =
            _measuredCardHeight(outgoingChapterNo) ?? outgoingExpanded;
        delta -= outgoingStart - outgoingCompact;
      }
    }

    return delta;
  }

  /// 하단 챕터: 포커스 중앙 정렬 대신, 펼침과 동시에 예측된 최종 목표치로
  /// 딱 한 번 병렬 스크롤한다. 중간 레이아웃 변화를 실시간으로 쫓지 않으므로
  /// 위아래로 튕기지 않는다.
  void _startBottomPinScroll(int chapterNo) {
    if (_expandedChapterNo != chapterNo) return;
    final position = _scrollPositionOrNull;
    if (position == null) return;
    if (_activeCenterScrollChapter == chapterNo && _suppressScrollExpand) {
      return;
    }

    final generation = _scrollGeneration;
    _activeCenterScrollChapter = chapterNo;
    _suppressScrollExpand = true;
    if (_initialFocusPending) _initialFocusPending = false;

    final delta = _predictedContentHeightDelta(
      chapterNo: chapterNo,
      outgoingChapterNo: _outgoingExpandedChapterNo,
    );
    final target = math.max(
      position.minScrollExtent,
      position.maxScrollExtent + delta,
    );

    _stopScrollAnimation();

    if ((target - position.pixels).abs() >= 0.5) {
      position.animateTo(
        target,
        duration: LearningHubChapterCard.expandAnimationDuration,
        curve: LearningHubChapterCard.expandAnimationCurve,
      );
    }

    Future.delayed(
      LearningHubChapterCard.expandAnimationDuration +
          const Duration(milliseconds: 40),
      () {
        if (!mounted ||
            _expandedChapterNo != chapterNo ||
            _scrollGeneration != generation) {
          return;
        }
        _outgoingExpandedChapterNo = null;
        setState(() => _transientBottomSlack = 0);
        _awaitingFinalize = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              _expandedChapterNo != chapterNo ||
              _scrollGeneration != generation) {
            return;
          }
          _waitForLayoutSettle(chapterNo, generation, () {
            if (!mounted ||
                _expandedChapterNo != chapterNo ||
                _scrollGeneration != generation) {
              return;
            }
            _awaitingFinalize = false;
            _suppressScrollExpand = false;
            _activeCenterScrollChapter = null;
            if (_userInterruptedFinalize) return;
            _snapToMaxScrollExtent();
          });
        });
      },
    );
  }

  /// 큰 레이아웃 변화(슬랙 제거 등) 직후에는 SliverList의
  /// maxScrollExtent가 한두 프레임 동안 아직 다 갱신되지 않은 "덜 짓다
  /// 만" 값을 보여줄 수 있다 — 이 상태에서 바로 최종 보정을 하면 잘못된
  /// 위치로 갔다가 다음 프레임에 다시 맞는 자리로 되돌아오는 이중
  /// 점핑이 생긴다. 그래서 고정된 시간이 아니라, maxScrollExtent가
  /// "연속된 두 프레임에서 같은 값"이 될 때까지 기다린 뒤에만 최종
  /// 보정을 실행한다.
  void _waitForLayoutSettle(
    int chapterNo,
    int generation,
    VoidCallback onSettled, {
    int maxFrames = 20,
  }) {
    double? lastMax;

    void checkFrame(int framesLeft) {
      if (!mounted ||
          _expandedChapterNo != chapterNo ||
          _scrollGeneration != generation) {
        return;
      }
      final position = _scrollPositionOrNull;
      if (position == null) {
        onSettled();
        return;
      }
      final currentMax = position.maxScrollExtent;
      final stable = lastMax != null && (currentMax - lastMax!).abs() < 0.5;
      lastMax = currentMax;
      if (stable || framesLeft <= 0) {
        onSettled();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkFrame(framesLeft - 1);
      });
    }

    checkFrame(maxFrames);
  }

  void _scheduleExpandedScrollFinalize(int chapterNo, {required int generation}) {
    final token = Object();
    _scrollFinalizeToken = token;
    Future.delayed(
      LearningHubChapterCard.expandAnimationDuration +
          const Duration(milliseconds: 40),
      () {
        if (!mounted ||
            _scrollFinalizeToken != token ||
            _expandedChapterNo != chapterNo ||
            _scrollGeneration != generation) {
          return;
        }
        _outgoingExpandedChapterNo = null;
        setState(() => _transientBottomSlack = 0);
        _awaitingFinalize = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              _scrollFinalizeToken != token ||
              _expandedChapterNo != chapterNo ||
              _scrollGeneration != generation) {
            return;
          }
          _waitForLayoutSettle(chapterNo, generation, () {
            if (!mounted ||
                _scrollFinalizeToken != token ||
                _expandedChapterNo != chapterNo ||
                _scrollGeneration != generation) {
              return;
            }
            _awaitingFinalize = false;
            _suppressScrollExpand = false;
            _activeCenterScrollChapter = null;
            if (_userInterruptedFinalize) return;
            _animateChapterToViewportCenter(chapterNo, animate: false);
            _clampScrollToMax();
          });
        });
      },
    );
  }

  void _onHubLanguageChanged(String language) {
    final oldController = _scrollController;
    _stopScrollAnimation();

    _expandedChapterNo = null;
    _outgoingExpandedChapterNo = null;
    _transientBottomSlack = 0;
    _initialFocusPending = true;
    _initialFocusQueued = false;
    _precachedImagesLanguage = null;
    _compactScrollMode = false;
    _scrollGeneration++;
    _scrollFinalizeToken = null;
    _awaitingFinalize = false;
    _userInterruptedFinalize = false;
    _activeCenterScrollChapter = null;
    _suppressScrollExpand = false;

    // 1단계: 기존 ListView를 먼저 완전히 내린다. 같은 ScrollController와
    // GlobalKey가 이전·새 ListView에 동시에 붙으면 duplicate key / multiple
    // scroll views 에러가 난다.
    setState(() => _hubListVisible = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _displayLanguage = language;
      _chapterHeights.clear();
      _listEpoch++;
      _scrollController = ScrollController();
      setState(() => _hubListVisible = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    });
  }

  void _precacheChapterHeroImages(
    BuildContext context,
    String language,
    List<LearningHubChapter> chapters,
  ) {
    if (_precachedImagesLanguage == language) return;
    _precachedImagesLanguage = language;
    for (final chapter in chapters) {
      final path = resolveHubChapterIcon(
        chapterImage: chapter.chapterImage,
        category: chapter.name,
      );
      if (path.isEmpty) continue;
      precacheImage(AssetImage(path), context);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _displayLanguage = ref.read(learningHubLanguageProvider);
    ref.listenManual(learningHubLanguageProvider, (previous, next) {
      if (previous == next) return;
      _onHubLanguageChanged(next);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _chapterCardWidth(BuildContext context) {
    final inset = Active5Layout.of(context).pagePadding.left;
    return MediaQuery.sizeOf(context).width - inset * 2;
  }

  /// 카드가 4:3 fallback이 아닌 실제 히어로 이미지 비율로 펼쳐질 최종
  /// 높이를 추정한다. fallback만 쓰면 실제 이미지 비율과 어긋나
  /// "추정 후 나중에 실측값으로 보정"할 때 큰 오차(그리고 튕김)가 생긴다.
  double _estimateExpandedHeightFor(int chapterNo, BuildContext context) {
    final chapter = _chaptersByNo[chapterNo];
    final assetPath = chapter == null
        ? ''
        : resolveHubChapterIcon(
            chapterImage: chapter.chapterImage,
            category: chapter.name,
          );
    final cachedRatio = assetPath.isEmpty
        ? null
        : LearningHubChapterCard.aspectRatioCache[assetPath];
    return LearningHubChapterCard.estimateExpandedBlockHeight(
      _chapterCardWidth(context),
      aspectRatio:
          cachedRatio ?? LearningHubChapterCard.fallbackAspectRatio,
    );
  }

  /// 펼친 카드가 자연 스크롤 범위 안에서 보이도록 목표 offset 계산.
  /// 인위적 하단 spacer 없이 maxScrollExtent까지만 사용한다.
  ///
  /// 카드가 가용 밴드(bandTop~focusY 구간)보다 커서 중앙 정렬 시 카드
  /// 상단이 헤더 위로 올라가야 하는 경우(=화면 상단 근처 카드가 매우 큰
  /// 히어로 이미지로 펼쳐질 때) 중앙 정렬 대신 카드 상단을 헤더 바로
  /// 아래에 맞춘다. 그렇지 않으면 "중앙에 맞추려다 불가능하니 반대로
  /// 크게 아래로 밀려버리는" 점프가 발생한다.
  double _scrollTargetForExpandedChapter({
    required ScrollPosition position,
    required double futureTop,
    required double expandedHeight,
    required double bandTop,
    required double focusY,
  }) {
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    final current = position.pixels;

    final maxCenterableHeight = 2 * (focusY - bandTop);
    double result;
    if (expandedHeight > maxCenterableHeight) {
      result = (current + (futureTop - bandTop)).clamp(min, max);
    } else {
      final centerTarget =
          current + (futureTop + expandedHeight / 2 - focusY);
      if (centerTarget <= max + 0.5) {
        result = centerTarget.clamp(min, max);
      } else {
        final topTarget = current + (futureTop - focusY);
        if (topTarget <= max + 0.5) {
          result = topTarget.clamp(min, max);
        } else {
          result = max;
        }
      }
    }
    return result;
  }

  /// 펼침·접힘 완료 레이아웃을 가정해, 펼침과 동시에 뷰포트 포커스 위치로 스크롤.
  bool _animateChapterToViewportCenter(
    int chapterNo, {
    bool animate = true,
  }) {
    if (_expandedChapterNo != chapterNo) return false;
    final position = _scrollPositionOrNull;
    if (position == null) return false;

    final cardTop = _cardTopForChapter(chapterNo);
    final focusY = _viewportFocusY(context);
    final estimatedExpanded = _estimateExpandedHeightFor(chapterNo, context);
    final targetIndex = _orderedChapterNos.indexOf(chapterNo);
    final targetIsLast = targetIndex >= 0 &&
        targetIndex == _orderedChapterNos.length - 1;
    final compactH =
        LearningHubChapterCard.compactBlockHeight(isLast: targetIsLast);
    final measured = _measuredCardHeight(chapterNo);
    // 펼치는 중이면 최종 블록 높이(패딩 포함)로 한 번에 계산.
    final expandedHeight = measured != null && measured >= compactH + 24
        ? measured
        : estimatedExpanded;

    var futureTop = cardTop;
    final outgoing = _outgoingExpandedChapterNo;
    if (outgoing != null && outgoing != chapterNo) {
      final outgoingIndex = _orderedChapterNos.indexOf(outgoing);
      if (outgoingIndex >= 0 && targetIndex > outgoingIndex) {
        final outgoingIsLast =
            outgoingIndex == _orderedChapterNos.length - 1;
        final outgoingCompact = LearningHubChapterCard.compactBlockHeight(
          isLast: outgoingIsLast,
        );
        final outgoingHeight = _measuredCardHeight(outgoing) ??
            _estimateExpandedHeightFor(outgoing, context);
        futureTop -= math.max(0.0, outgoingHeight - outgoingCompact);
      }
    }

    final target = _scrollTargetForExpandedChapter(
      position: position,
      futureTop: futureTop,
      expandedHeight: expandedHeight,
      bandTop: _viewportBandTop(context),
      focusY: focusY,
    );

    if ((target - position.pixels).abs() < 0.5) return true;

    _stopScrollAnimation();

    if (animate) {
      position.animateTo(
        target,
        duration: LearningHubChapterCard.expandAnimationDuration,
        curve: LearningHubChapterCard.expandAnimationCurve,
      );
    } else {
      _softCorrectScroll(position, target);
    }
    return true;
  }

  void _startParallelCenterScroll(int chapterNo) {
    if (_expandedChapterNo != chapterNo) return;
    if (_isNearBottomChapter(chapterNo)) {
      _startBottomPinScroll(chapterNo);
      return;
    }
    if (_activeCenterScrollChapter == chapterNo && _suppressScrollExpand) {
      return;
    }

    final generation = _scrollGeneration;
    _activeCenterScrollChapter = chapterNo;
    _suppressScrollExpand = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _expandedChapterNo != chapterNo ||
          _scrollGeneration != generation) {
        return;
      }

      final started = _animateChapterToViewportCenter(chapterNo);
      if (started && _initialFocusPending) _initialFocusPending = false;
      if (!started) {
        _suppressScrollExpand = false;
        _activeCenterScrollChapter = null;
        return;
      }

      _scheduleExpandedScrollFinalize(chapterNo, generation: generation);
    });
  }

  /// 스크롤 종료 시 판정 — flick(속도 우선) vs 느린 긴 드래그(컴팩트).
  void _onUserScrollEnd(ScrollEndNotification notification) {
    if (_suppressScrollExpand || _initialFocusPending) return;

    final dragDetails = notification.dragDetails;
    final pointerVelocity =
        dragDetails?.velocity.pixelsPerSecond.dy ?? 0;
    final dragDelta = _safeScrollOffset() - _scrollDragStartOffset;

    final flickSpeed =
        math.max(pointerVelocity.abs(), _scrollPeakVelocity.abs());

    // 빠른 flick → (최소 이동 거리를 넘긴 경우에 한해) 챕터 스냅
    if (flickSpeed >= _shortSwipeVelocityPx &&
        dragDelta.abs() >= _minFlickDistancePx) {
      // offset 증가(손가락 위) = 다음 챕터
      final direction = _scrollPeakVelocity.abs() >= pointerVelocity.abs()
          ? (_scrollPeakVelocity > 0 ? 1 : -1)
          : (pointerVelocity > 0 ? -1 : 1);
      _jumpToAdjacentChapter(direction);
      return;
    }

    // 느린 긴 드래그 → 컴팩트 리스트
    if (dragDelta.abs() >= _longDragThresholdPx && !_compactScrollMode) {
      _scrollGeneration++;
      _scrollFinalizeToken = null;
      setState(() {
        _compactScrollMode = true;
        _expandedChapterNo = null;
        _outgoingExpandedChapterNo = null;
        _transientBottomSlack = 0;
      });
    }

    _clampScrollToMax();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_hubListVisible) return false;
    // 최종 보정을 기다리는 동안(우리가 스스로 애니메이션을 걸지 않는
    // 구간)에 도착하는 스크롤 알림은 전부 사용자가 마우스 휠/드래그로
    // 직접 스크롤을 시도한 것이다 — 이때는 뒤에 나올 강제 보정이 사용자
    // 위치를 다시 덮어쓰지 않도록 표시만 해둔다.
    if (_awaitingFinalize &&
        (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification)) {
      _userInterruptedFinalize = true;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _scrollDragStartOffset = _safeScrollOffset();
      _isUserDragScroll = true;
      _scrollPeakVelocity = 0;
      _scrollSampleOffset = _safeScrollOffset();
      _scrollSampleTime = null;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final now = DateTime.now();
      final offset = notification.metrics.pixels;
      final sampleTime = _scrollSampleTime;
      if (sampleTime == null) {
        _scrollSampleTime = now;
        _scrollSampleOffset = offset;
      } else {
        final dtMs = now.difference(sampleTime).inMilliseconds;
        // 표본 간 시간이 한 프레임(≈16ms)보다 짧으면, 같은 프레임에
        // 배치 처리된 포인터 이벤트 등 타이밍 잡음 때문에 실제보다
        // 훨씬 큰 속도로 계산될 수 있다 — "길게 누르고 천천히 드래그"
        // 해도 그 순간의 잡음 하나 때문에 flick(챕터 스냅)으로 오판되는
        // 버그의 원인이었다. 충분히 신뢰할 수 있는 간격이 쌓일 때까지
        // 기준점을 유지하고 기다린다.
        if (dtMs >= 16) {
          final v = (offset - _scrollSampleOffset) / dtMs * 1000;
          if (v.abs() > _scrollPeakVelocity.abs()) {
            _scrollPeakVelocity = v;
          }
          _scrollSampleTime = now;
          _scrollSampleOffset = offset;
        }
      }
    } else if (notification is ScrollEndNotification && _isUserDragScroll) {
      _isUserDragScroll = false;
      _scrollSampleTime = null;
      _onUserScrollEnd(notification);
    }
    return false;
  }

  int? _nearestChapterToViewport() {
    final position = _scrollPositionOrNull;
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (position == null || viewportBox == null || !viewportBox.attached) {
      return null;
    }

    final focusY = _viewportFocusY(context);
    final listTop = viewportBox.localToGlobal(Offset.zero).dy;
    final scroll = position.pixels;

    int? nearestChapterNo;
    var nearestDistance = double.infinity;
    var offset = _listPaddingTop;
    for (var i = 0; i < _orderedChapterNos.length; i++) {
      final chapterNo = _orderedChapterNos[i];
      final height = _heightForChapter(chapterNo);
      final top = listTop + offset - scroll;
      final center = top + height / 2;
      final distance = (center - focusY).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestChapterNo = chapterNo;
      }
      offset += height;
    }
    return nearestChapterNo;
  }

  void _focusChapter(
    int chapterNo, {
    bool animateScroll = true,
    bool swipeSnap = false,
  }) {
    _scrollGeneration++;
    _scrollFinalizeToken = null;
    _stopScrollAnimation();
    _awaitingFinalize = false;
    _userInterruptedFinalize = false;
    final previous = _compactScrollMode ? null : _expandedChapterNo;
    final slack = animateScroll ? _computeTransientSlack(chapterNo) : 0.0;
    setState(() {
      _compactScrollMode = false;
      _outgoingExpandedChapterNo =
          (previous != null && previous != chapterNo) ? previous : null;
      _expandedChapterNo = chapterNo;
      _transientBottomSlack = math.max(_transientBottomSlack, slack);
      if (swipeSnap) _chapterSnapToken++;
    });
    if (swipeSnap) {
      HapticFeedback.lightImpact();
    }
    if (!animateScroll) return;
    _startParallelCenterScroll(chapterNo);
  }

  void _jumpToAdjacentChapter(int direction) {
    if (_orderedChapterNos.isEmpty) return;

    final anchor = _compactScrollMode
        ? (_nearestChapterToViewport() ?? _orderedChapterNos.first)
        : (_expandedChapterNo ?? _nearestChapterToViewport() ?? _orderedChapterNos.first);
    final index = _orderedChapterNos.indexOf(anchor);
    if (index < 0) return;

    final nextIndex = index + direction;
    if (nextIndex < 0 || nextIndex >= _orderedChapterNos.length) return;

    final position = _scrollPositionOrNull;
    if (position != null) {
      position.jumpTo(position.pixels);
    }

    _focusChapter(_orderedChapterNos[nextIndex], swipeSnap: true);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Active5Layout.of(context);
    final inset = metrics.pagePadding.left;
    final language = _displayLanguage;
    final contentAsync = ref.watch(contentProvider);
    final sentenceProgress = ref.watch(sentenceProgressProvider);
    final swipeProgress = ref.watch(swipeProgressProvider);
    final scenarioProgress = ref.watch(scenarioProgressProvider);
    final sentenceRepo = ref.watch(sentenceProgressRepositoryProvider);

    return contentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('학습 화면 로드 실패: $e')),
      data: (content) {
        final bundle = content.bundle;
        final chapters = bundle.learningHubChaptersFor(language);
        _precacheChapterHeroImages(context, language, chapters);
        final resume = _hubCurriculumResume(
          chapters: chapters,
          language: language,
          bundle: bundle,
          sentenceProgress: sentenceProgress,
          swipeProgress: swipeProgress,
          scenarioProgress: scenarioProgress,
          sentenceRepo: sentenceRepo,
        );
        if (chapters.isNotEmpty && _initialFocusPending && !_initialFocusQueued) {
          _initialFocusQueued = true;
          _expandedChapterNo ??= resume.firstIncompleteNo;
          _suppressScrollExpand = true;
        }
        final expandedChapterNo = _compactScrollMode
            ? null
            : (_expandedChapterNo ?? resume.firstIncompleteNo);
        final completedChapters = resume.completedCount;
        _orderedChapterNos =
            chapters.map((chapter) => chapter.chapterNo).toList(growable: false);
        _chaptersByNo = {
          for (final chapter in chapters) chapter.chapterNo: chapter,
        };

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 카드 리스트 — 화면 최상단(메인 헤더 바로 아래)까지 꽉 채워
                // 스크롤된다. 카드 자체는 손대지 않고, 화면 상단에 얹는
                // 고정 스크림(아래)이 경계를 부드럽게 만든다.
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    key: _viewportKey,
                    onNotification: _handleScrollNotification,
                    child: _hubListVisible
                        ? ListView(
                        key: ValueKey('hub_list_$_listEpoch'),
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        clipBehavior: Clip.none,
                        padding: EdgeInsets.fromLTRB(
                          inset,
                          _listPaddingTop,
                          inset,
                          _listBottomPadding(context),
                        ),
                        children: [
                          if (chapters.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 48),
                              child: Center(
                                child: Text(
                                  '이 언어의 학습 데이터가 아직 없어요.\n콘텐츠 동기화 후 다시 시도해 주세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: DashboardPalette.textMuted,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < chapters.length; i++) ...[
                              _HubChapterCardLoader(
                                // chapterNo만으로는 유일성이 보장되지 않는다
                                // (learningHubChaptersFor의 병합 키는
                                // "chapterNo|name" 조합) — 같은 chapterNo를
                                // 쓰는 카테고리가 둘 이상이면 chapterNo만
                                // 쓴 key가 중복되어 ListView 내부 sliver의
                                // child order assertion이 터진다. name까지
                                // 포함해 항상 고유하게 만든다.
                                key: ValueKey(
                                  'hub_card_${_listEpoch}_${chapters[i].chapterNo}_${chapters[i].name}',
                                ),
                                chapter: chapters[i],
                                language: language,
                                bundle: bundle,
                                sentenceProgress: sentenceProgress,
                                swipeProgress: swipeProgress,
                                scenarioProgress: scenarioProgress,
                                sentenceRepo: sentenceRepo,
                                isExpanded: expandedChapterNo != null &&
                                    chapters[i].chapterNo == expandedChapterNo,
                                isLast: i == chapters.length - 1,
                                snapToken: expandedChapterNo != null &&
                                        chapters[i].chapterNo ==
                                            expandedChapterNo
                                    ? _chapterSnapToken
                                    : 0,
                                onHeightChanged: _onChapterHeightChanged,
                                onExpandRequested: () => _focusChapter(
                                  chapters[i].chapterNo,
                                ),
                              ),
                            ],
                        ],
                      )
                        : const SizedBox.shrink(),
                    ),
                  ),
                // 화면 맨 위 고정 스크림 — 카드나 리스트를 건드리지 않고,
                // 화면 상단에만 옅게 얹어 그 아래로 스크롤되는 카드가
                // 뚝 끊기지 않고 배경 쪽으로 자연스럽게 사라지도록 한다.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _topScrimHeight,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _topScrimGradient(context),
                      ),
                    ),
                  ),
                ),
                // 프로그레스 바 — 카드 위에 얹혀 화면 맨 위에 고정되는
                // frosted glass 플로팅 헤더. 레이아웃 공간을 점유하지 않고
                // Positioned로 카드 위에 떠 있으므로, 카드는 그 밑으로
                // 계속 스크롤되어 메인 헤더까지 올라갈 수 있다.
                Positioned(
                  top: -AppHeader.bodyGap,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    key: ValueKey('hub_header_scroll_$_listEpoch'),
                    animation: _scrollController,
                    builder: (context, child) {
                      final offset = _safeScrollOffset();
                      final opacity = _floatingHeaderOpacityFor(offset);
                      return Opacity(
                        opacity: opacity,
                        child: IgnorePointer(
                          ignoring: opacity < 0.05,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: math.max(8.0, inset - 8),
                      ),
                      child: CascadeEntrance(
                        child: _LearningHubSectionHeader(
                          totalChapters: chapters.length,
                          completedChapters: completedChapters,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
  }
}

({int completedCount, int? firstIncompleteNo}) _hubCurriculumResume({
  required List<LearningHubChapter> chapters,
  required String language,
  required ContentBundle bundle,
  required SentenceProgressState sentenceProgress,
  required SwipeProgressState swipeProgress,
  required ScenarioProgressState scenarioProgress,
  required SentenceProgressRepository sentenceRepo,
}) {
  var completedCount = 0;
  int? firstIncompleteNo;

  for (final chapter in chapters) {
    final done = _isHubChapterComplete(
      chapter: chapter,
      language: language,
      bundle: bundle,
      sentenceProgress: sentenceProgress,
      swipeProgress: swipeProgress,
      scenarioProgress: scenarioProgress,
      sentenceRepo: sentenceRepo,
    );
    if (done) {
      completedCount++;
    } else {
      firstIncompleteNo ??= chapter.chapterNo;
    }
  }

  return (
    completedCount: completedCount,
    firstIncompleteNo: firstIncompleteNo ??
        (chapters.isEmpty ? null : chapters.last.chapterNo),
  );
}

bool _isHubChapterComplete({
  required LearningHubChapter chapter,
  required String language,
  required ContentBundle bundle,
  required SentenceProgressState sentenceProgress,
  required SwipeProgressState swipeProgress,
  required ScenarioProgressState scenarioProgress,
  required SentenceProgressRepository sentenceRepo,
}) {
  final category = chapter.name;
  final words = bundle.wordsFor(language, category);
  final sentences = bundle.sentencesFor(language, category);
  final scenarios = bundle.scenariosForHubChapter(language, chapter);
  final swipeCat = swipeProgress.stats.forCategory(language, category);
  final sentenceSummary = sentences.isEmpty
      ? null
      : sentenceRepo.categorySummary(
          sentences: sentences,
          stats: sentenceProgress.stats,
        );

  bool isScenarioCompleted(String id) =>
      scenarioProgress.stats.isCompleted(language, id);

  return LearningHubChapterCard.isWordModeComplete(
        words.length,
        words.isEmpty ? null : swipeCat,
      ) &&
      LearningHubChapterCard.isSentenceModeComplete(sentenceSummary) &&
      LearningHubChapterCard.isScenarioModeComplete(
        scenarios,
        isScenarioCompleted,
      );
}

class _LearningHubSectionHeader extends StatelessWidget {
  final int totalChapters;
  final int completedChapters;

  const _LearningHubSectionHeader({
    required this.totalChapters,
    required this.completedChapters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HubGrooveProgressTrack(
            current: completedChapters,
            total: totalChapters,
          ),
          const SizedBox(height: 7),
          Text(
            '$completedChapters/$totalChapters',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: Color.lerp(
                context.requireLanguagePalette.canvas,
                const Color(0xFF1E293B),
                0.72,
              )!,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubChapterCardLoader extends StatefulWidget {
  final LearningHubChapter chapter;
  final String language;
  final ContentBundle bundle;
  final SentenceProgressState sentenceProgress;
  final SwipeProgressState swipeProgress;
  final ScenarioProgressState scenarioProgress;
  final SentenceProgressRepository sentenceRepo;
  final bool isExpanded;
  final bool isLast;
  final int snapToken;
  final void Function(int chapterNo, double height)? onHeightChanged;
  final VoidCallback onExpandRequested;

  const _HubChapterCardLoader({
    super.key,
    required this.chapter,
    required this.language,
    required this.bundle,
    required this.sentenceProgress,
    required this.swipeProgress,
    required this.scenarioProgress,
    required this.sentenceRepo,
    required this.isExpanded,
    required this.isLast,
    this.snapToken = 0,
    this.onHeightChanged,
    required this.onExpandRequested,
  });

  @override
  State<_HubChapterCardLoader> createState() => _HubChapterCardLoaderState();
}

class _HubChapterCardLoaderState extends State<_HubChapterCardLoader>
    with SingleTickerProviderStateMixin {
  static const _revealDuration = Duration(milliseconds: 280);

  bool _heroReady = false;
  bool _loadInFlight = false;
  Object? _loadToken;
  late final AnimationController _reveal;
  late final Animation<double> _revealT;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: _revealDuration);
    _revealT = CurvedAnimation(parent: _reveal, curve: Curves.easeOut);
    // 이 에셋이 이미 한 번 실측된 적이 있다면(다른 카드가 먼저 로드했거나,
    // 스크롤로 이 카드가 재활용되어 다시 만들어진 경우) 굳이 다시
    // precacheImage를 기다릴 필요 없이 바로 표시한다. 그렇지 않으면
    // 재활용될 때마다 카드가 잠깐 0 높이("로딩 중")로 접혔다가 다시
    // 펼쳐지면서 리스트 스크롤 범위 계산이 흔들린다.
    if (_isAssetAlreadyKnown()) {
      _heroReady = true;
      _reveal.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHeroImage());
    }
  }

  bool _isAssetAlreadyKnown() {
    final path = resolveHubChapterIcon(
      chapterImage: widget.chapter.chapterImage,
      category: widget.chapter.name,
    );
    return path.isEmpty ||
        LearningHubChapterCard.aspectRatioCache.containsKey(path);
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _reportHeight() {
    if (!mounted) return;
    final onHeightChanged = widget.onHeightChanged;
    if (onHeightChanged == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.height <= 0) return;
    onHeightChanged(widget.chapter.chapterNo, box.size.height);
  }

  @override
  void didUpdateWidget(covariant _HubChapterCardLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.chapterImage != widget.chapter.chapterImage ||
        oldWidget.chapter.name != widget.chapter.name) {
      _loadToken = Object();
      _heroReady = false;
      _loadInFlight = false;
      _reveal.reset();
      _loadHeroImage();
    }
    if (oldWidget.isExpanded != widget.isExpanded ||
        oldWidget.isLast != widget.isLast ||
        oldWidget.snapToken != widget.snapToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
    }
  }

  Future<void> _loadHeroImage() async {
    if (_loadInFlight || _heroReady) return;
    _loadInFlight = true;

    final path = resolveHubChapterIcon(
      chapterImage: widget.chapter.chapterImage,
      category: widget.chapter.name,
    );

    if (path.isEmpty) {
      _markHeroReady();
      return;
    }

    final token = Object();
    _loadToken = token;
    try {
      await precacheImage(AssetImage(path), context);
    } catch (_) {
      // errorBuilder 폴백으로 카드는 표시
    }

    if (!mounted || _loadToken != token) return;
    _markHeroReady();
  }

  void _markHeroReady() {
    if (!mounted || _heroReady) return;
    setState(() => _heroReady = true);
    _reveal.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  @override
  Widget build(BuildContext context) {
    if (!_heroReady) return const SizedBox.shrink();

    final category = widget.chapter.name;
    final words = widget.bundle.wordsFor(widget.language, category);
    final sentences = widget.bundle.sentencesFor(widget.language, category);
    final scenarios =
        widget.bundle.scenariosForHubChapter(widget.language, widget.chapter);
    final swipeCat =
        widget.swipeProgress.stats.forCategory(widget.language, category);
    final sentenceSummary = widget.sentenceRepo.categorySummary(
      sentences: sentences,
      stats: widget.sentenceProgress.stats,
    );

    bool isScenarioCompleted(String id) =>
        widget.scenarioProgress.stats.isCompleted(widget.language, id);

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: FadeTransition(
          opacity: _revealT,
          child: LearningHubChapterCard(
            chapter: widget.chapter,
            language: widget.language,
            wordCount: words.length,
            isExpanded: widget.isExpanded,
            isLast: widget.isLast,
            snapToken: widget.snapToken,
            onExpandRequested: widget.onExpandRequested,
            swipeProgress: words.isEmpty ? null : swipeCat,
            sentenceSummary: sentences.isEmpty ? null : sentenceSummary,
            scenarios: scenarios,
            isScenarioCompleted: isScenarioCompleted,
            onWordPlay: words.isEmpty
                ? null
                : () => openWordSwipeFromHub(
                      context,
                      language: widget.language,
                      category: category,
                    ),
            onWordReview: !swipeCat.played || swipeCat.unknownCount == 0
                ? null
                : () => openWordSwipeFromHub(
                      context,
                      language: widget.language,
                      category: category,
                      reviewOnly: true,
                    ),
            onSentencePlay: sentences.isEmpty
                ? null
                : () => openSentenceTrainingFromHub(
                      context,
                      language: widget.language,
                      category: category,
                    ),
          ),
        ),
      ),
    );
  }
}
