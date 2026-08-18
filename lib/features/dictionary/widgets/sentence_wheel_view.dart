import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/learning_tour_providers.dart';
import '../../../app/providers.dart';
import '../../../app/speech_providers.dart';
import '../../../core/config/active5_layout.dart';
import '../../../core/services/audio_prefetch.dart';
import '../../../core/theme/language_palette.dart';
import '../../../data/models/sentence.dart';
import '../../../features/basic_sentence/widgets/in_flight_briefing_tour.dart';
import '../../../features/dashboard/dashboard_palette.dart';
import 'wheel_learning_panel.dart';

/// 스냅 타겟이 아닌 카드 — 배경으로 밀되 문장은 읽을 수 있을 정도로 유지.
const _kInactiveOpacity = 0.62;

/// 드래그 포커스 모드 — 스냅 타겟 외 영역 딤 강도.
/// 3D 휠 스텝 간격(카드 높이 아님) — 슬롯 중심 간 거리만 결정한다.
/// `_NeighborPreview`가 영문 2줄 + 한글 1줄로 높이가 상한선(bound)까지만
/// 늘어나도록(`maxLines`) 고정해 두었으므로, 이 값은 그 상한 높이보다
/// 살짝 작게만 잡아도 이웃 카드끼리 심하게 겹치지 않는다.
const _kWheelItemExtent = 60.0;

/// 동적 카드가 슬롯 밖으로 늘어날 수 있는 최대 높이(안전 상한). 텍스트가
/// `maxLines`로 제한돼 있어 실제 콘텐츠 높이는 이 값을 넘지 않으므로,
/// RenderFlex 오버플로우 없이 항상 이 상한 안에서만 그려진다.
const _kMaxCardOverflowHeight = 112.0;

class SentenceWheelView extends ConsumerStatefulWidget {
  final List<Sentence> sentences;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;
  final VoidCallback? onCompleted;
  final BuildContext? tourOverlayContext;

  const SentenceWheelView({
    super.key,
    required this.sentences,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.onCompleted,
    this.tourOverlayContext,
  });

  @override
  ConsumerState<SentenceWheelView> createState() => _SentenceWheelViewState();
}

class _SentenceWheelViewState extends ConsumerState<SentenceWheelView>
    with TickerProviderStateMixin {
  late FixedExtentScrollController _controller;
  late AnimationController _swipeHintController;
  late AnimationController _expandController;
  late AnimationController _snapShimmerController;
  late AudioController _audioController;
  late SpeechPracticeController _speechPracticeController;

  int _currentIndex = 0;
  bool _hideSwipeHint = false;
  bool _hideCompletionHint = false;
  bool _completionTriggered = false;
  bool _isAnimatingSwap = false;
  bool _isDragging = false;
  bool _tourScheduled = false;

  final LearningTourTargetKeys _tourKeys = LearningTourTargetKeys();

  /// 3D 휠 스텝 간격 — `_kWheelItemExtent`와 동일(별칭).
  static const _itemExtent = _kWheelItemExtent;
  static const _diameterRatio = 2.5;
  static const _perspective = 0.0015;
  static const _squeeze = 0.72;

  /// 반대쪽 끝에서 더는 넘어갈 곳이 없을 때 주는 저항 배율.
  static const _kEdgeResistance = 0.35;

  /// 이 속도(px/s) 이상으로 손가락을 튕기면 드래그 거리와 무관하게 정확히
  /// 한 칸만 이동하는 '퀵 스와이프'로 판정한다.
  static const _kQuickSwipeVelocity = 350.0;

  /// 3D 휠이 목표 인덱스로 정착하는 데 걸리는 시간(연속 드래그 기준) —
  /// 릴리즈 스냅이 부드럽게 '착' 감기는 느낌을 주도록 300ms.
  static const _kSettleDuration = Duration(milliseconds: 300);

  /// 퀵 스와이프 전용 초고속 스냅 시간.
  static const _kQuickSwipeDuration = Duration(milliseconds: 140);

  /// 손대는 즉시 '찰싹' 접히는 폴드다운 모션 — 짧고 급격하게(easeInCubic).
  static const _kFoldDuration = Duration(milliseconds: 100);

  /// 정착 후 콤팩트 요약 → 풀 학습 패널로 펼쳐지는 데 걸리는 시간 — 릴리즈
  /// 스냅과 동일한 타임라인으로 함께 움직여야 하므로 300ms로 동기화.
  static const _kUnfoldDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _audioController = ref.read(audioProvider.notifier);
    _speechPracticeController = ref.read(speechPracticeProvider.notifier);
    _currentIndex = widget.initialIndex.clamp(
      0,
      math.max(0, widget.sentences.length - 1),
    );
    _controller = FixedExtentScrollController(initialItem: _currentIndex);
    // 1.0 = Focus 모드(풀 학습 패널). 드래그가 시작되면 100ms 만에 0으로 접혔다가
    // 정착 후에만 200ms easeOutCubic 타임라인을 타고 다시 1로 펼쳐진다.
    _expandController = AnimationController(
      vsync: this,
      duration: _kUnfoldDuration,
      value: 1.0,
    );
    // 한 방향(위로 스와이프 → 다음) 스토리텔링용 루프
    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    // 드래그 중 스냅 후보 카드에 흐르는 45도 시머링 — 드래그가 진행되는
    // 동안에만 repeat()되고, 손을 떼면 즉시 정지·리셋된다.
    _snapShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onIndexChanged?.call(_currentIndex);
      AudioPrefetch.around(widget.sentences, _currentIndex);
      _scheduleInitialTour();
    });
  }

  Future<void> _scheduleInitialTour() async {
    if (_tourScheduled || !mounted) return;
    _tourScheduled = true;

    final completed = await ref
        .read(learningTourLocalDataSourceProvider)
        .hasCompletedLearningTour();
    if (!mounted || completed) return;

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _startBriefingTour(force: false);
  }

  Future<void> _startBriefingTour({required bool force}) async {
    if (!mounted || InFlightBriefingTour.isShowing) return;

    final overlayContext = widget.tourOverlayContext ?? context;
    if (!overlayContext.mounted) return;

    final sentence = widget.sentences[_currentIndex];
    final includeSpeedStep = sentence.audioUrl.isNotEmpty;

    await InFlightBriefingTour.show(
      context: overlayContext,
      keys: _tourKeys,
      includeSpeedStep: includeSpeedStep,
      onComplete: () async {
        await ref
            .read(learningTourLocalDataSourceProvider)
            .setCompletedLearningTour(true);
      },
      onSkip: () async {
        await ref
            .read(learningTourLocalDataSourceProvider)
            .setCompletedLearningTour(true);
      },
    );
  }

  @override
  void didUpdateWidget(SentenceWheelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sentences.length != oldWidget.sentences.length) {
      _currentIndex = _currentIndex.clamp(
        0,
        math.max(0, widget.sentences.length - 1),
      );
      _expandController.value = 1.0;
      if (_controller.hasClients) {
        _controller.jumpToItem(_currentIndex);
      }
    }
  }

  @override
  void dispose() {
    final audio = _audioController;
    final speech = _speechPracticeController;
    // dispose 중 provider 수정은 Riverpod에서 금지 — 프레임 종료 후 정리.
    Future(() async {
      await audio.stop();
      speech.reset();
    });
    _swipeHintController.dispose();
    _expandController.dispose();
    _snapShimmerController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onUserSwiped() {
    if (!_hideSwipeHint) {
      setState(() => _hideSwipeHint = true);
    }
  }

  bool get _isLastCard =>
      widget.sentences.isNotEmpty &&
      _currentIndex >= widget.sentences.length - 1;

  /// 마지막 카드에서 위로 스와이프(완료) 커밋.
  bool _tryTriggerCompletion({required bool wantsForward}) {
    if (!wantsForward || !_isLastCard || _completionTriggered) return false;

    if (_controller.hasClients) {
      _controller.jumpTo(_currentIndex * _itemExtent);
    }

    setState(() {
      _hideCompletionHint = true;
      _completionTriggered = true;
    });

    widget.onCompleted?.call();
    return widget.onCompleted != null;
  }

  void _onCompletionChipTap() {
    if (_isAnimatingSwap) return;
    _tryTriggerCompletion(wantsForward: true);
  }

  /// 3D 휠을 [targetIndex]로 부드럽게 스크롤해 정착시키면서, 동시에 중앙
  /// 카드를 콤팩트 요약에서 풀 학습 패널로 펼친다(Concurrent Unfold — 휠이
  /// 자리를 잡을 때까지 기다리지 않고 처음부터 함께 움직여 체감 딜레이를
  /// 없앤다). 현재 인덱스로 호출하면 그대로 '스냅백'(원위치 복귀 + 재펼침)
  /// 으로 동작한다.
  Future<void> _settleTo(int targetIndex, {Duration? settleDuration}) async {
    if (_isAnimatingSwap) return;
    _isAnimatingSwap = true;
    _onUserSwiped();

    final changed = targetIndex != _currentIndex;
    if (changed) {
      _audioController.stop();
      _speechPracticeController.reset();
      setState(() => _currentIndex = targetIndex);
      widget.onIndexChanged?.call(targetIndex);
      AudioPrefetch.around(widget.sentences, targetIndex);
    }

    final wheelFuture = _controller.hasClients
        ? _controller.animateToItem(
            targetIndex,
            duration: settleDuration ?? _kSettleDuration,
            curve: Curves.easeOutCubic,
          )
        : Future<void>.value();
    final expandFuture = _expandController.animateTo(
      1,
      duration: _kUnfoldDuration,
      curve: Curves.easeOutCubic,
    );

    await Future.wait([wheelFuture, expandFuture]);
    if (!mounted) return;
    _isAnimatingSwap = false;
  }

  /// 이웃 카드 탭 — 드래그 커밋과 동일한 정착 연출로 이동해 손맛을 통일한다.
  void _navigateTo(int targetIndex) {
    if (_isAnimatingSwap) return;
    final clamped = targetIndex.clamp(0, widget.sentences.length - 1);
    if (clamped == _currentIndex) return;
    _settleTo(clamped);
  }

  void _onMainDragStart(DragStartDetails details) {
    if (_isAnimatingSwap) return;
    setState(() => _isDragging = true);
    _snapShimmerController.repeat();
    // 손대는 순간 순삭이 아니라, 100ms easeInCubic 타임라인을 타고 '찰싹'
    // 접히듯 3D 휠 요약 카드 규격으로 수축한다.
    _expandController.animateTo(
      0,
      duration: _kFoldDuration,
      curve: Curves.easeInCubic,
    );
  }

  void _onMainDragUpdate(DragUpdateDetails details) {
    if (_isAnimatingSwap) return;
    _onUserSwiped();

    var delta = details.primaryDelta ?? 0;
    final hasNext = _currentIndex < widget.sentences.length - 1;
    final hasPrev = _currentIndex > 0;

    if (delta < 0 && !hasNext) {
      delta *= _kEdgeResistance; // 다음 문장이 없으면 저항감 부여
    } else if (delta > 0 && !hasPrev) {
      delta *= _kEdgeResistance; // 이전 문장이 없으면 저항감 부여
    }

    // 손가락 delta를 3D 휠 오프셋에 1:1로 그대로 반영 — 카드와 휠이 완전히
    // 하나의 물체처럼 움직인다.
    if (_controller.hasClients) {
      final maxOffset = (widget.sentences.length - 1) * _itemExtent;
      final nextOffset = (_controller.offset - delta).clamp(0.0, maxOffset);
      _controller.jumpTo(nextOffset);
    }
  }

  void _onMainDragEnd(DragEndDetails details) {
    if (_isAnimatingSwap) return;
    setState(() => _isDragging = false);
    _snapShimmerController
      ..stop()
      ..value = 0;

    final velocity = details.primaryVelocity ?? 0;
    final hasNext = _currentIndex < widget.sentences.length - 1;
    final hasPrev = _currentIndex > 0;

    // 퀵 스와이프 — 손가락을 튕기면 드래그한 거리는 완전히 무시하고, 방향만
    // 보고 정확히 한 칸만 140ms 초고속으로 스냅한다. 먼저 휠 오프셋을 현재
    // 정착 인덱스 위치로 되돌려(jumpTo) 애니메이션의 시작점을 고정하므로,
    // 빠르게 멀리 드래그했더라도 여러 칸이 스킵되어 보이는 현상이 없다.
    if (velocity.abs() > _kQuickSwipeVelocity) {
      if (_controller.hasClients) {
        _controller.jumpTo(_currentIndex * _itemExtent);
      }
      if (velocity < 0 && !hasNext) {
        if (_tryTriggerCompletion(wantsForward: true)) return;
        _settleTo(_currentIndex, settleDuration: _kQuickSwipeDuration);
      } else if (velocity < 0 && hasNext) {
        _settleTo(_currentIndex + 1, settleDuration: _kQuickSwipeDuration);
      } else if (velocity > 0 && hasPrev) {
        _settleTo(_currentIndex - 1, settleDuration: _kQuickSwipeDuration);
      } else {
        _settleTo(_currentIndex, settleDuration: _kQuickSwipeDuration);
      }
      return;
    }

    // 연속 드래그 — 손을 놓은 시점의 휠 오프셋에서 가장 가까운 인덱스로
    // 자연스럽게 정착한다(여러 칸을 한 번에 밀었다면 그만큼 이동).
    final nearestIndex = _controller.hasClients
        ? (_controller.offset / _itemExtent)
            .round()
            .clamp(0, widget.sentences.length - 1)
        : _currentIndex;

    if (!hasNext && _controller.hasClients) {
      final overshoot =
          _controller.offset - _currentIndex * _itemExtent;
      final wantsForward =
          overshoot > _itemExtent * 0.22 || velocity < -120;
      if (_tryTriggerCompletion(wantsForward: wantsForward)) return;
    }

    _settleTo(nearestIndex);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(learningTourReplaySignalProvider, (prev, next) {
      if ((prev ?? 0) < next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startBriefingTour(force: true);
        });
      }
    });

    if (widget.sentences.isEmpty) {
      return const Center(child: Text('이 카테고리에 문장이 없습니다.'));
    }

    final palette = context.languagePalette;
    final accent = palette?.accent ?? Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPad = (constraints.maxWidth * 0.04).clamp(12.0, 20.0);
        // 휠 스냅 타겟·메인 카드가 동일한 가로 폭을 쓰도록 inset 통일.
        final cardSideInset = horizontalPad * 0.65;
        // 하단 인덱스(1/6)와 플레이헤드·말하기 덱이 항상 보이도록 카드 높이 상한.
        // 긴 문장(영문 2줄 + 한국어)이 잘리지 않도록 본문 여유를 충분히 확보한다.
        const bottomChrome = 48.0;
        final maxFocusHeight = ((constraints.maxHeight - bottomChrome) * 0.72)
            .clamp(300.0, 480.0);
        final maxFocusWidth = constraints.maxWidth - cardSideInset * 2;
        final isLastCard = _currentIndex >= widget.sentences.length - 1;

        // 최상위 GestureDetector가 배경 휠·딤·메인 카드·버튼을 모두 조상으로
        // 감싸므로, 카드 내부(빈 공간·텍스트 위)를 터치해도 100% 드래그가
        // 인식된다. 버튼 탭은 (움직임이 없으면) 여전히 탭 인식기가 이긴다.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onMainDragStart,
          onVerticalDragUpdate: _onMainDragUpdate,
          onVerticalDragEnd: _onMainDragEnd,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 레이어 1: 단일 3D 휠 — 모든 슬롯(중앙 포함)이 동일한 요약 카드
              // 규격으로 정렬되어 손가락 delta와 1:1로 함께 구른다. 어둡게
              // 톤다운하는 딤 레이어 없이 항상 밝고 또렷하게 유지한다.
              Positioned.fill(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (Rect bounds) =>
                      _wheelFadeShader(bounds, maxFocusHeight),
                  child: ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: _itemExtent,
                    perspective: _perspective,
                    diameterRatio: _diameterRatio,
                    squeeze: _squeeze,
                    clipBehavior: Clip.none,
                    useMagnifier: false,
                    physics: const NeverScrollableScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.sentences.length,
                      builder: (context, index) {
                        return _WheelSlotItem(
                          index: index,
                          currentIndex: _currentIndex,
                          horizontalPadding: horizontalPad,
                          cardSideInset: cardSideInset,
                          sentence: widget.sentences[index],
                          onTap: () => _navigateTo(index),
                          controller: _controller,
                          itemExtent: _itemExtent,
                          centerExpand: _expandController,
                          accent: accent,
                          isDragging: _isDragging,
                          shimmerAnimation: _snapShimmerController,
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 레이어 2: 펼쳐진 중앙 카드 + 스와이프 코치 — 투어 5단계 컷홀 타겟.
              Align(
                alignment: Alignment.center,
                child: KeyedSubtree(
                  key: _tourKeys.swipeKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_hideSwipeHint && widget.sentences.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _WheelSwipeCoach(
                            animation: _swipeHintController,
                            accent: accent,
                            hasNext:
                                _currentIndex < widget.sentences.length - 1,
                          ),
                        ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxFocusWidth,
                          maxHeight: maxFocusHeight,
                        ),
                        child: _CenterFocusCard(
                          key: ValueKey(widget.sentences[_currentIndex].id),
                          sentence: widget.sentences[_currentIndex],
                          displayIndex: _currentIndex + 1,
                          totalCount: widget.sentences.length,
                          horizontalPadding: 0,
                          accent: accent,
                          expand: _expandController,
                          fullHeight: maxFocusHeight,
                          tourKeys: _tourKeys,
                          onNextSentence: _currentIndex <
                                  widget.sentences.length - 1
                              ? () => _settleTo(_currentIndex + 1)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 마지막 카드 하단 — Shimmer 글래스 완료 칩.
              if (!_hideCompletionHint &&
                  isLastCard &&
                  widget.onCompleted != null)
                Positioned(
                  bottom: 48,
                  left: horizontalPad,
                  right: horizontalPad,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _CompletionGlassChip(
                      onTap: _onCompletionChipTap,
                    ),
                  ),
                ),

              Positioned(
                bottom: 10,
                child: IgnorePointer(
                  child: _IndexIndicator(
                    current: _currentIndex + 1,
                    total: widget.sentences.length,
                    accent: accent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Shader _wheelFadeShader(Rect bounds, double focusHeight) {
  final h = bounds.height;
  if (h <= 0) {
    return const LinearGradient(colors: [Colors.white, Colors.white])
        .createShader(bounds);
  }

  final halfNorm = (focusHeight / 2) / h;
  final fadeNorm = (36.0 / h).clamp(0.05, 0.14);
  final solidTop = (0.5 - halfNorm).clamp(0.0, 1.0);
  final solidBottom = (0.5 + halfNorm).clamp(0.0, 1.0);
  final fadeTop = (solidTop - fadeNorm).clamp(0.0, 1.0);
  final fadeBottom = (solidBottom + fadeNorm).clamp(0.0, 1.0);

  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: const [
      Colors.transparent,
      Colors.black,
      Colors.black,
      Colors.transparent,
    ],
    stops: [0.0, fadeTop, fadeBottom, 1.0],
  ).createShader(bounds);
}

class _WheelSlotItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final double horizontalPadding;
  final double cardSideInset;
  final Sentence sentence;
  final VoidCallback onTap;
  final ScrollController controller;
  final double itemExtent;

  /// 중앙(정착) 슬롯에서만 의미를 갖는 펼침 진행도(0=Browse 요약,
  /// 1=Focus 완전 펼침). 값이 커질수록 이 요약 프리뷰는 사라지고(오버레이 풀
  /// 카드가 대신 보임), 0으로 접히면(드래그 시작) 다른 슬롯과 완전히 동일한
  /// 모습으로 복귀한다.
  final Animation<double> centerExpand;
  final Color accent;

  /// 유저가 손가락으로 3D 휠을 드래그하고 있는 중인지 — 스냅 후보 카드의
  /// 시머링·포커스 링은 드래그 중에만 표시한다.
  final bool isDragging;

  /// 드래그 중 스냅 후보 카드에 흐르는 45도 백색 시머 애니메이션.
  final Animation<double> shimmerAnimation;

  const _WheelSlotItem({
    required this.index,
    required this.currentIndex,
    required this.horizontalPadding,
    required this.cardSideInset,
    required this.sentence,
    required this.onTap,
    required this.controller,
    required this.itemExtent,
    required this.centerExpand,
    required this.accent,
    required this.isDragging,
    required this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isCenterSlot = index == currentIndex;

    return AnimatedBuilder(
      animation: Listenable.merge([controller, centerExpand, shimmerAnimation]),
      builder: (context, _) {
        // 휠 중심 오프셋에 가장 가까운 인덱스를 실시간으로 계산 — 휠이
        // 굴러갈 때마다 스냅 타겟 카드가 '착착착' 지나가며 하이라이트된다.
        final liveOffset =
            controller.hasClients ? controller.offset : index * itemExtent;
        final nearestIndex = (liveOffset / itemExtent).round();
        final isActiveTarget = index == nearestIndex;
        // 지금 손을 떼면 이 카드가 선택된다 — 드래그 중에만 반짝인다.
        final showSnapGlow = isDragging && isActiveTarget;

        var slotOpacity = isActiveTarget ? 1.0 : _kInactiveOpacity;

        final isWideLayout = isCenterSlot || isActiveTarget;

        final preview = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWideLayout ? cardSideInset : horizontalPadding * 1.1,
          ),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Align(
              alignment: Alignment.center,
              // 슬롯(itemExtent)은 촘촘하게 유지하고, 카드만 콘텐츠 높이만큼
              // 위아래로 자연스럽게 넘치게 그린다(clipBehavior: Clip.none 휠).
              child: OverflowBox(
                minHeight: 0,
                maxHeight: _kMaxCardOverflowHeight,
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: showSnapGlow ? 1.015 : (isActiveTarget ? 1.02 : 1.0),
                  alignment: Alignment.center,
                  child: _NeighborPreview(
                    sentence: sentence,
                    displayIndex: index + 1,
                    isActiveTarget: isActiveTarget,
                    showSnapGlow: showSnapGlow,
                    shimmerAnimation: shimmerAnimation,
                  ),
                ),
              ),
            ),
          ),
        );

        if (!isCenterSlot) {
          return Align(
            alignment: Alignment.center,
            child: Opacity(opacity: slotOpacity, child: preview),
          );
        }

        final focusT = centerExpand.value.clamp(0.0, 1.0);
        return Align(
          alignment: Alignment.center,
          child: Opacity(
            opacity: (1 - focusT) * slotOpacity,
            child: IgnorePointer(
              ignoring: focusT > 0.5,
              child: preview,
            ),
          ),
        );
      },
    );
  }
}

class _CenterFocusCard extends StatelessWidget {
  final Sentence sentence;
  final int displayIndex;
  final int totalCount;
  final double horizontalPadding;
  final Color accent;

  /// 0 = Browse(요약, 완전 투명) · 1 = Focus(풀 학습 패널, 완전 표출).
  final Animation<double> expand;

  /// 카드가 커질 수 있는 최대 높이 — 실제 렌더 높이는 항상 내부 컨텐츠의
  /// 실제 높이에 맞춰지고, 이 값은 안전 상한선(cap)으로만 쓰인다.
  final double fullHeight;
  final LearningTourTargetKeys? tourKeys;
  final VoidCallback? onNextSentence;

  const _CenterFocusCard({
    super.key,
    required this.sentence,
    required this.displayIndex,
    required this.totalCount,
    required this.horizontalPadding,
    required this.accent,
    required this.expand,
    required this.fullHeight,
    this.tourKeys,
    this.onNextSentence,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      // 무거운 학습 패널은 `child`로 캐시해 펼침 애니메이션 프레임마다
      // 재생성되지 않도록 한다(마이크·오디오 상태도 그대로 유지됨).
      child: AnimatedBuilder(
        animation: expand,
        builder: (context, learningPanel) {
          final t = expand.value.clamp(0.0, 1.0);
          // 펼침과 함께 1.0 → 1.02로 떠오르는 3D 부유 스케일.
          final scale = 1.0 + 0.02 * t;

          return IgnorePointer(
            ignoring: t < 0.5,
            child: Opacity(
              opacity: t,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: Padding(
                  // 2중 그림자가 부모 ConstrainedBox에 잘리지 않도록 여백 확보.
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 12 * t + 4),
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08 * t),
                            blurRadius: 20,
                            offset: Offset(0, 8 * t),
                          ),
                          BoxShadow(
                            color: accent.withValues(alpha: 0.12 * t),
                            blurRadius: 10,
                            offset: Offset(0, 4 * t),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: _WheelCardGlassShell(
                          borderRadius: BorderRadius.circular(24),
                          fillColor: Colors.white.withValues(alpha: 0.92),
                          blurSigma: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 1.0,
                              ),
                            ),
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: t,
                                child: ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxHeight: fullHeight),
                                  child: learningPanel,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          );
        },
        child: WheelLearningPanel(
          sentence: sentence,
          accent: accent,
          displayIndex: displayIndex,
          totalCount: totalCount,
          tourKeys: tourKeys,
          onNextSentence: onNextSentence,
        ),
      ),
    );
  }
}

class _NeighborPreview extends StatelessWidget {
  static const _chipColor = Color(0xFF64748B);

  final Sentence sentence;
  final int displayIndex;

  /// 3D 휠 중심에 가장 가까운(다음 스냅 대상) 카드인지 여부 — 맑은 리얼
  /// 글래스 + 살짝 커진 크기로 '착!' 하고 눈에 띄는 Active Preview Indicator.
  final bool isActiveTarget;

  /// 드래그 중 "지금 손을 떼면 이 카드가 선택됨"을 알리는 시머·포커스 링.
  final bool showSnapGlow;
  final Animation<double> shimmerAnimation;

  const _NeighborPreview({
    required this.sentence,
    required this.displayIndex,
    required this.isActiveTarget,
    required this.showSnapGlow,
    required this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = Active5Layout.of(context);
    final scheme = Theme.of(context).colorScheme;
    const duration = Duration(milliseconds: 150);
    final detailOpacity = isActiveTarget ? 1.0 : 0.72;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (showSnapGlow) ...[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ] else if (isActiveTarget) ...[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ] else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(
                alpha: isActiveTarget ? 0.92 : 0.58,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 22, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              sentence.sentence,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: metrics.sentenceFontSize - 1,
                                fontWeight: isActiveTarget
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: isActiveTarget
                                    ? DashboardPalette.navy
                                    : scheme.onSurface.withValues(alpha: 0.72),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (sentence.korean.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          sentence.korean,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: metrics.koreanFontSize - 1,
                            fontWeight: FontWeight.w600,
                            color: isActiveTarget
                                ? DashboardPalette.navy.withValues(alpha: 0.65)
                                : Colors.grey.shade600.withValues(alpha: 0.68),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 8,
                  child: Opacity(
                    opacity: detailOpacity,
                    child: _PreviewIndexChip(
                      label: displayIndex.toString().padLeft(2, '0'),
                      isActiveTarget: isActiveTarget,
                    ),
                  ),
                ),
                if (showSnapGlow)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _SnapShimmerOverlay(
                          animation: shimmerAnimation,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 좌상단 콤팩트 문장 번호 뱃지 — `01`, `02` … 테두리 없이 그림자로만
/// 살짝 떠 있는 느낌을 주는 미니멀 스타일.
class _PreviewIndexChip extends StatelessWidget {
  final String label;
  final bool isActiveTarget;

  const _PreviewIndexChip({
    required this.label,
    required this.isActiveTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActiveTarget ? 0.85 : 0.55),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActiveTarget ? 0.10 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: _NeighborPreview._chipColor.withValues(
            alpha: isActiveTarget ? 0.85 : 0.48,
          ),
          height: 1.1,
        ),
      ),
    );
  }
}

/// 드래그 중 스냅 후보 카드 표면을 좌->우로 스르륵 흐르는 45도 백색 시머.
class _SnapShimmerOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _SnapShimmerOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return ClipRect(
          child: Align(
            alignment: Alignment(-1.6 + 3.2 * t, 0),
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: FractionallySizedBox(
                widthFactor: 0.26,
                heightFactor: 2.6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
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

/// 위로 스와이프 → 다음 문장. 메인 카드 바로 위, 배경 위 직접 표출.
class _WheelSwipeCoach extends StatelessWidget {
  final Animation<double> animation;
  final Color accent;
  final bool hasNext;

  const _WheelSwipeCoach({
    required this.animation,
    required this.accent,
    required this.hasNext,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasNext) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        // 0~0.2 대기 → 0.2~0.55 위로 스와이프 → 0.55~0.75 홀드 → 0.75~1 리셋
        late final double swipe;
        if (t < 0.2) {
          swipe = 0;
        } else if (t < 0.55) {
          swipe = Curves.easeInOutCubic.transform((t - 0.2) / 0.35);
        } else if (t < 0.75) {
          swipe = 1;
        } else {
          swipe = 1 - Curves.easeIn.transform((t - 0.75) / 0.25);
        }

        final fingerY = 26.0 - swipe * 32.0;
        final currentCardY = -swipe * 20.0;
        final currentOpacity = (1.0 - swipe * 0.85).clamp(0.15, 1.0);
        final nextCardY = 22.0 - swipe * 22.0;
        final nextOpacity = (0.25 + swipe * 0.75).clamp(0.25, 1.0);
        final nextScale = 0.88 + swipe * 0.12;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, nextCardY),
                    child: Transform.scale(
                      scale: nextScale,
                      child: Opacity(
                        opacity: nextOpacity,
                        child: _CoachMiniCard(
                          accent: accent,
                          label: '다음',
                          emphasized: swipe > 0.45,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, currentCardY),
                    child: Opacity(
                      opacity: currentOpacity,
                      child: _CoachMiniCard(
                        accent: accent.withValues(alpha: 0.55),
                        label: '지금',
                        emphasized: false,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    top: fingerY,
                    child: Icon(
                      Icons.swipe_up_alt_rounded,
                      size: 24,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_double_arrow_up_rounded,
                  size: 17,
                  color: accent,
                ),
                const SizedBox(width: 2),
                Text(
                  '위로 스와이프',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '다음 문장이 아래에서 올라와요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DashboardPalette.navy.withValues(alpha: 0.68),
                height: 1.2,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 마지막 카드 — Shimmer 글래스 완료 칩 (탭 또는 위로 스와이프).
class _CompletionGlassChip extends StatefulWidget {
  final VoidCallback? onTap;

  const _CompletionGlassChip({this.onTap});

  @override
  State<_CompletionGlassChip> createState() => _CompletionGlassChipState();
}

class _CompletionGlassChipState extends State<_CompletionGlassChip>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const slate = Color(0xFF334155);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '모든 문장 학습을 마쳤어요. 다음 챕터로 이동해요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: slate.withValues(alpha: 0.95),
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '✨',
                          style: TextStyle(
                            fontSize: 12,
                            color: slate.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, _) {
                          return ClipRect(
                            child: Align(
                              alignment: Alignment(
                                -1.0 + 2.0 * _shimmerController.value,
                                0,
                              ),
                              child: FractionallySizedBox(
                                widthFactor: 0.38,
                                heightFactor: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.42),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachMiniCard extends StatelessWidget {
  final Color accent;
  final String label;
  final bool emphasized;

  const _CoachMiniCard({
    required this.accent,
    required this.label,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: emphasized ? accent : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: emphasized ? 0.9 : 0.35),
          width: emphasized ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: emphasized ? 0.28 : 0.1),
            blurRadius: emphasized ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: emphasized ? Colors.white : accent,
        ),
      ),
    );
  }
}

class _IndexIndicator extends StatelessWidget {
  final int current;
  final int total;
  final Color accent;

  const _IndexIndicator({
    required this.current,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Text(
        '$current / $total',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

/// Flutter Web CanvasKit에서 BackdropFilter + 코치마크 오버레이 saveLayer 크래시 방지.
class _WheelCardGlassShell extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color fillColor;
  final double blurSigma;
  final Widget child;

  const _WheelCardGlassShell({
    required this.borderRadius,
    required this.fillColor,
    this.blurSigma = 16,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: fillColor,
      borderRadius: borderRadius,
    );

    if (kIsWeb) {
      return DecoratedBox(
        decoration: decoration,
        child: child,
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: DecoratedBox(
        decoration: decoration,
        child: child,
      ),
    );
  }
}
