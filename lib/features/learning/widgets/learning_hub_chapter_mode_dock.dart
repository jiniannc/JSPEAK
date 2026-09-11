import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/scenario_providers.dart';
import '../../../app/shell_providers.dart';
import '../../../app/sentence_progress_providers.dart';
import '../../../app/swipe_progress_providers.dart';
import '../../../data/datasources/local/swipe_progress_local_datasource.dart';
import '../../../data/models/scenario.dart';
import '../../../data/models/sentence.dart';
import '../../../data/repositories/sentence_progress_repository.dart';
import '../../../shared/widgets/flight_progress_bar.dart';
import 'scenario_picker_overlay.dart';
import 'sentence_group_picker.dart';
import 'word_swipe_picker_overlay.dart';

/// 챕터 카드 우하단 — 맥OS 스타일 학습 모드 아이콘 도크.
class ChapterModeDock extends ConsumerStatefulWidget {
  const ChapterModeDock({
    super.key,
    required this.revealAnimation,
    required this.wordCount,
    required this.swipeProgress,
    required this.wordComplete,
    required this.sentenceSummary,
    required this.sentences,
    required this.sentenceComplete,
    required this.language,
    required this.sentenceCategory,
    required this.sentenceChapterNo,
    required this.scenarios,
    required this.scenarioComplete,
    required this.isScenarioCompleted,
  });

  static const tileSize = 62.0;
  static const tileGap = 4.0;
  static const bottomInset = 14.0;
  static const rightInset = 8.0;
  static const labelHeight = 11.0;
  static const progressHeight = 2.0;
  static const progressGap = 5.0;
  static const progressBarWidthRatio = 0.8;
  static const iconVisualInsetRatio = 0.06;
  static const iconVisualWidth = tileSize * (1 - iconVisualInsetRatio * 2);
  static const reservedWidth = tileSize * 3 + tileGap * 2 + rightInset + 6;

  /// 프로그레스 바 상단 — Chapter 라벨과 수평 정렬 기준.
  static const progressRowBottomInset =
      bottomInset + labelHeight + progressGap + tileSize + progressGap;

  static const dockBlockHeight =
      progressHeight + progressGap + tileSize + progressGap + labelHeight;

  static const modeIconAssets = <String>[
    'assets/images/icon_word.png',
    'assets/images/icon_sentence.png',
    'assets/images/icon_scenario.png',
  ];

  static const _modeIconMaxCacheSize = 240;
  static const _modeIconCacheMultiplier = 1.75;

  static int modeIconCacheSizeFor(double devicePixelRatio) {
    return (tileSize * devicePixelRatio * _modeIconCacheMultiplier)
        .round()
        .clamp(1, _modeIconMaxCacheSize);
  }

  static ImageProvider modeIconProvider({
    required String assetPath,
    required double devicePixelRatio,
  }) {
    final cacheSize = modeIconCacheSizeFor(devicePixelRatio);
    return ResizeImage(
      AssetImage(assetPath),
      width: cacheSize,
      height: cacheSize,
    );
  }

  static Future<void> precacheModeIcons(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Future.wait(
      modeIconAssets.map(
        (path) => precacheImage(modeIconProvider(assetPath: path, devicePixelRatio: dpr), context),
      ),
    );
  }

  final Animation<double> revealAnimation;

  final int wordCount;
  final SwipeCategoryProgress? swipeProgress;
  final bool wordComplete;
  final SentenceCategorySummary? sentenceSummary;
  final List<Sentence> sentences;
  final bool sentenceComplete;
  final String language;
  final String sentenceCategory;
  final int sentenceChapterNo;
  final List<Scenario> scenarios;
  final bool scenarioComplete;
  final bool Function(String scenarioId) isScenarioCompleted;

  @override
  ConsumerState<ChapterModeDock> createState() => _ChapterModeDockState();
}

class _ChapterModeDockState extends ConsumerState<ChapterModeDock> {
  final GlobalKey _wordAnchorKey = GlobalKey();
  final GlobalKey _sentenceAnchorKey = GlobalKey();
  final GlobalKey _scenarioAnchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final resync = ref.watch(hubDockResyncProvider);
    final swipeStats = ref.watch(swipeProgressProvider).stats;
    final swipeCat = swipeStats.forCategory(
      widget.language,
      widget.sentenceCategory,
    );
    final wordRatio = swipeCat.knownRatioForDisplay(
      fallbackTotal: widget.wordCount,
    );

    final sentenceProgress = ref.watch(sentenceProgressProvider);
    final sentenceRepo = ref.read(sentenceProgressRepositoryProvider);
    final sentenceSummary = widget.sentences.isEmpty
        ? widget.sentenceSummary
        : sentenceRepo.categorySummary(
            sentences: widget.sentences,
            stats: sentenceProgress.stats,
          );
    final sentenceTotal = sentenceSummary?.total ?? 0;
    final sentenceRatio = sentenceSummary?.stampRatio ?? 0.0;

    final scenarioStats = ref.watch(scenarioProgressProvider).stats;
    final scenarioTotal = widget.scenarios.length;
    final scenarioDone = widget.scenarios
        .where((s) => scenarioStats.isCompleted(widget.language, s.id))
        .length;
    final scenarioRatio = scenarioTotal <= 0
        ? 0.0
        : (scenarioDone / scenarioTotal).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DockStaggerSlot(
          index: 0,
          revealAnimation: widget.revealAnimation,
          child: KeyedSubtree(
            key: _wordAnchorKey,
            child: _MacDockIcon(
              staggerIndex: 0,
              resyncEpoch: resync.epoch,
              resyncFullReveal: resync.fullReveal,
              revealAnimation: widget.revealAnimation,
              assetPath: 'assets/images/icon_word.png',
              label: '단어 스와이프',
              maxLabelLines: 1,
              progress: wordRatio,
              accentColor: HubTripleModeProgressTrack.wordColor,
              enabled: widget.wordCount > 0,
              phase: 0.0,
              onTap: widget.wordCount > 0
                  ? () => openWordSwipePicker(
                        context,
                        ref: ref,
                        language: widget.language,
                        category: widget.sentenceCategory,
                        wordCount: widget.wordCount,
                        popupAnchorKey: _wordAnchorKey,
                      )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: ChapterModeDock.tileGap),
        _DockStaggerSlot(
          index: 1,
          revealAnimation: widget.revealAnimation,
          child: KeyedSubtree(
            key: _sentenceAnchorKey,
            child: _MacDockIcon(
              staggerIndex: 1,
              resyncEpoch: resync.epoch,
              resyncFullReveal: resync.fullReveal,
              revealAnimation: widget.revealAnimation,
              assetPath: 'assets/images/icon_sentence.png',
              label: '문장 스피킹',
              maxLabelLines: 1,
              progress: sentenceRatio,
              accentColor: HubTripleModeProgressTrack.sentenceRed,
              enabled: sentenceTotal > 0,
              phase: 0.33,
              onTap: sentenceTotal > 0
                  ? () => openSentenceTraining(
                        context,
                        ref: ref,
                        language: widget.language,
                        category: widget.sentenceCategory,
                        chapterNo: widget.sentenceChapterNo,
                        popupAnchorKey: _sentenceAnchorKey,
                      )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: ChapterModeDock.tileGap),
        _DockStaggerSlot(
          index: 2,
          revealAnimation: widget.revealAnimation,
          child: KeyedSubtree(
            key: _scenarioAnchorKey,
            child: _MacDockIcon(
              staggerIndex: 2,
              resyncEpoch: resync.epoch,
              resyncFullReveal: resync.fullReveal,
              revealAnimation: widget.revealAnimation,
              assetPath: 'assets/images/icon_scenario.png',
              label: '실전 롤플레잉',
              maxLabelLines: 1,
              progress: scenarioRatio,
              accentColor: HubTripleModeProgressTrack.scenarioColor,
              enabled: scenarioTotal > 0,
              phase: 0.66,
              onTap: scenarioTotal > 0
                  ? () => openScenarioPicker(
                        context,
                        ref: ref,
                        scenarios: widget.scenarios,
                        isCompleted: widget.isScenarioCompleted,
                        popupAnchorKey: _scenarioAnchorKey,
                      )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _DockStaggerSlot extends StatelessWidget {
  const _DockStaggerSlot({
    required this.index,
    required this.revealAnimation,
    required this.child,
  });

  final int index;
  final Animation<double> revealAnimation;
  final Widget child;

  double _rawProgress(double expand) {
    const base = 0.04;
    final start = base + index * 0.14;
    final end = (start + 0.38).clamp(0.0, 1.0);
    if (expand <= start) return 0;
    if (expand >= end) return 1;
    return ((expand - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// 0 → 1.42 overshoot → 0.94 undershoot → 1.0 settle
  double _popScale(double raw) {
    if (raw <= 0) return 0;
    if (raw >= 1) return 1;
    if (raw < 0.48) {
      return Curves.easeOutBack.transform(raw / 0.48) * 1.42;
    }
    if (raw < 0.72) {
      final squash = (raw - 0.48) / 0.24;
      return 1.42 - Curves.easeIn.transform(squash) * 0.48;
    }
    final settle = (raw - 0.72) / 0.28;
    return 0.94 + Curves.elasticOut.transform(settle) * 0.06;
  }

  double _popOpacity(double raw) {
    if (raw <= 0) return 0;
    if (raw >= 1) return 1;
    return Curves.easeOut.transform((raw * 3.4).clamp(0.0, 1.0));
  }

  double _popLiftY(double raw) {
    if (raw <= 0) return 28;
    if (raw >= 1) return 0;
    return 28 * (1 - Curves.easeOutBack.transform(raw));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: revealAnimation,
      builder: (context, child) {
        final raw = _rawProgress(revealAnimation.value.clamp(0.0, 1.0));
        if (raw <= 0) {
          return IgnorePointer(
            child: Opacity(opacity: 0, child: child),
          );
        }

        final scale = _popScale(raw);
        final opacity = _popOpacity(raw);
        final liftY = _popLiftY(raw);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, liftY),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 도크 리빌 — 프로그레스 슬라이드·채움·완료 체크 타이밍.
class _DockProgressTiming {
  const _DockProgressTiming._();

  static const _stagger = 0.08;

  static double _segment(
    double expand,
    int index, {
    required double start,
    required double length,
  }) {
    final segStart = start + index * _stagger;
    final segEnd = (segStart + length).clamp(0.0, 1.0);
    if (expand <= segStart) return 0;
    if (expand >= segEnd) return 1;
    return ((expand - segStart) / (segEnd - segStart)).clamp(0.0, 1.0);
  }

  /// 바가 아래에서 올라오며 등장.
  static double entrance(double expand, int index) =>
      _segment(expand, index, start: 0.18, length: 0.12);

  /// 실제 진행률만큼 좌→우 채움.
  static double fill(double expand, int index) =>
      _segment(expand, index, start: 0.26, length: 0.40);

  /// 채움 완료 후 체크 배지 팝.
  static double check(double expand, int index) =>
      _segment(expand, index, start: 0.70, length: 0.18);
}

class _MacDockIcon extends StatefulWidget {
  const _MacDockIcon({
    required this.staggerIndex,
    required this.resyncEpoch,
    required this.resyncFullReveal,
    required this.revealAnimation,
    required this.assetPath,
    required this.label,
    required this.progress,
    required this.accentColor,
    required this.phase,
    this.maxLabelLines = 1,
    this.enabled = true,
    this.onTap,
  });

  final int staggerIndex;
  final int resyncEpoch;
  final bool resyncFullReveal;
  final Animation<double> revealAnimation;
  final String assetPath;
  final String label;
  final int maxLabelLines;
  final double progress;
  final Color accentColor;
  final double phase;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<_MacDockIcon> createState() => _MacDockIconState();
}

class _MacDockIconState extends State<_MacDockIcon>
    with TickerProviderStateMixin {
  late final AnimationController _press;
  late final AnimationController _deltaFill;
  late final AnimationController _returnCheck;

  double _settledProgress = 0;
  double _deltaFrom = 0;
  double _deltaTarget = 0;
  int _deltaFillGeneration = 0;
  bool _dockRevealed = false;
  bool _checkPinned = false;

  /// 학습·결과 화면 등 루트 오버레이가 허브 위에 있을 때는 delta를 돌리지 않는다.
  bool _isHubExposed() {
    final root = rootNavigatorKey.currentState;
    return root == null || !root.canPop();
  }

  static const _deltaFillDuration = Duration(milliseconds: 880);
  static const _returnCheckDuration = Duration(milliseconds: 560);

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 380),
    );
    _deltaFill = AnimationController(
      vsync: this,
      duration: _deltaFillDuration,
    )..addStatusListener(_onDeltaFillStatus);
    _returnCheck = AnimationController(
      vsync: this,
      duration: _returnCheckDuration,
    )..addStatusListener(_onReturnCheckStatus);
    widget.revealAnimation.addStatusListener(_onRevealStatus);
    if (widget.revealAnimation.value >= 0.995) {
      _dockRevealed = true;
      if (!widget.resyncFullReveal) {
        _settledProgress = widget.progress;
        _checkPinned = widget.progress >= 0.999;
      }
    }
    if (widget.resyncFullReveal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyFullRevealAnimation();
      });
    }
  }

  @override
  void activate() {
    super.activate();
    // 학습 화면(루트 라우트) 위에 있을 때 티커가 멈춰 delta가 완료되지 않을 수 있음.
    // 허브로 돌아올 때 최신 진행률로 다시 동기화한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncProgressToTarget();
    });
  }

  @override
  void didUpdateWidget(covariant _MacDockIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resyncEpoch != widget.resyncEpoch) {
      if (widget.resyncFullReveal) {
        _applyFullRevealAnimation();
      } else if (_isHubExposed()) {
        _syncProgressToTarget();
      }
      return;
    }
    if ((widget.progress - oldWidget.progress).abs() > 0.001) {
      if (_isHubExposed()) {
        _syncProgressToTarget();
      }
    }
  }

  /// 학습 탭 재진입 등 — 0부터 현재 진척도까지 전체 채움.
  void _applyFullRevealAnimation() {
    if (!_dockRevealed && widget.revealAnimation.value < 0.95) return;

    _deltaFillGeneration++;
    _deltaFill.stop();
    _returnCheck.stop();
    setState(() {
      _settledProgress = 0;
      _checkPinned = false;
      _dockRevealed = true;
    });
    _scheduleDeltaFill(from: 0, to: widget.progress.clamp(0.0, 1.0));
  }

  void _syncProgressToTarget() {
    final target = widget.progress.clamp(0.0, 1.0);
    final diff = target - _settledProgress;

    if (diff.abs() <= 0.001) {
      if (_deltaFill.isAnimating) return;
      if ((target - _displayProgress(widget.revealAnimation.value)).abs() >
          0.001) {
        setState(() => _settledProgress = target);
      }
      return;
    }

    // 티커가 멈춘 동안 delta가 끝까지 갔으면 재생 없이 스냅.
    if (!_deltaFill.isAnimating &&
        _deltaFill.status == AnimationStatus.completed &&
        (_deltaTarget - target).abs() <= 0.001) {
      setState(() {
        _settledProgress = target;
        _checkPinned = target >= 0.999;
      });
      return;
    }

    if (diff < 0) {
      _deltaFillGeneration++;
      _deltaFill.stop();
      _returnCheck.stop();
      setState(() {
        _settledProgress = target;
        _checkPinned = target >= 0.999;
      });
      return;
    }

    if (!_dockRevealed && widget.revealAnimation.value < 0.95) return;

    // 이미 같은 목표로 delta가 진행 중이면 재시작하지 않는다.
    if (_deltaFill.isAnimating && (_deltaTarget - target).abs() <= 0.001) {
      return;
    }

    final from = _deltaFill.isAnimating
        ? _deltaFrom +
            (_deltaTarget - _deltaFrom) *
                Curves.easeOutCubic.transform(_deltaFill.value)
        : _settledProgress;
    _scheduleDeltaFill(from: from, to: target);
  }

  @override
  void dispose() {
    widget.revealAnimation.removeStatusListener(_onRevealStatus);
    _press.dispose();
    _deltaFill.dispose();
    _returnCheck.dispose();
    super.dispose();
  }

  void _onRevealStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      setState(() {
        _dockRevealed = true;
        _settledProgress = widget.progress;
        _checkPinned = widget.progress >= 0.999;
      });
    } else if (status == AnimationStatus.dismissed) {
      _deltaFill.stop();
      _returnCheck.stop();
      setState(() {
        _dockRevealed = false;
        _settledProgress = 0;
        _checkPinned = false;
      });
    }
  }

  void _onDeltaFillStatus(AnimationStatus status) {
    if (!mounted || status != AnimationStatus.completed) return;
    final wasComplete = _settledProgress >= 0.999;
    setState(() {
      _settledProgress = _deltaTarget;
    });
    if (!wasComplete && _deltaTarget >= 0.999) {
      _returnCheck.forward(from: 0);
    } else if (_deltaTarget >= 0.999) {
      _checkPinned = true;
    }
  }

  void _onReturnCheckStatus(AnimationStatus status) {
    if (!mounted || status != AnimationStatus.completed) return;
    setState(() => _checkPinned = true);
  }

  void _scheduleDeltaFill({required double from, required double to}) {
    final clampedFrom = from.clamp(0.0, 1.0);
    final clampedTo = to.clamp(0.0, 1.0);

    if (_deltaFill.isAnimating &&
        (_deltaTarget - clampedTo).abs() <= 0.001 &&
        (_deltaFrom - clampedFrom).abs() <= 0.001) {
      return;
    }

    _deltaFrom = clampedFrom;
    _deltaTarget = clampedTo;
    _deltaFillGeneration++;
    final generation = _deltaFillGeneration;
    _deltaFill.stop();
    _returnCheck.stop();

    final delayMs = widget.staggerIndex * 95;
    if (delayMs <= 0) {
      _deltaFill.forward(from: 0);
      return;
    }
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted || generation != _deltaFillGeneration) return;
      if ((widget.progress - _deltaTarget).abs() > 0.001) {
        _deltaTarget = widget.progress.clamp(0.0, 1.0);
      }
      _deltaFill.forward(from: 0);
    });
  }

  double _displayProgress(double expand) {
    if (_deltaFill.isAnimating ||
        (_deltaFill.value > 0 && _deltaFill.status != AnimationStatus.completed)) {
      final t = Curves.easeOutCubic.transform(_deltaFill.value);
      return _deltaFrom + (_deltaTarget - _deltaFrom) * t;
    }

    if (_dockRevealed && expand >= 0.995) {
      return _settledProgress.clamp(0.0, 1.0);
    }

    final fillRaw = _DockProgressTiming.fill(expand, widget.staggerIndex);
    var fillCurve = Curves.easeOutCubic.transform(fillRaw);
    final target = widget.progress.clamp(0.0, 1.0);
    if (target >= 0.999 && fillRaw > 0.88) {
      final tail = ((fillRaw - 0.88) / 0.12).clamp(0.0, 1.0);
      fillCurve =
          (fillCurve + Curves.easeOutBack.transform(tail) * 0.04).clamp(0.0, 1.0);
    }
    return target * fillCurve;
  }

  double _checkReveal(double expand) {
    final isComplete = widget.progress >= 0.999;
    if (!isComplete) return 0;

    if (_returnCheck.isAnimating ||
        (_returnCheck.value > 0 && !_checkPinned)) {
      return Curves.elasticOut.transform(_returnCheck.value);
    }
    if (_checkPinned) return 1;

    if (!_dockRevealed || expand < 0.995) {
      return Curves.elasticOut.transform(
        _DockProgressTiming.check(expand, widget.staggerIndex),
      );
    }

    return _settledProgress >= 0.999 ? 1 : 0;
  }

  double _entranceRaw(double expand) {
    if (_dockRevealed && expand >= 0.995) return 1;
    return _DockProgressTiming.entrance(expand, widget.staggerIndex);
  }

  double _fillGlow(double expand, double displayValue) {
    final target = widget.progress.clamp(0.0, 1.0);
    final isComplete = target >= 0.999;

    if (_deltaFill.isAnimating ||
        (_deltaFill.value > 0 && _deltaFill.status != AnimationStatus.completed)) {
      if (!isComplete) return (_deltaFill.value * 0.35).clamp(0.0, 1.0);
      final tail = ((_deltaFill.value - 0.82) / 0.18).clamp(0.0, 1.0);
      return Curves.easeOut.transform(tail);
    }

    if (!isComplete) return 0;
    final fillRaw = _DockProgressTiming.fill(expand, widget.staggerIndex);
    if (fillRaw >= 0.92) {
      return ((fillRaw - 0.92) / 0.08).clamp(0.0, 1.0);
    }
    if (displayValue >= 0.999) return 1;
    return 0;
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled || widget.onTap == null) return;
    _press.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled || widget.onTap == null) return;
    _press.reverse(from: _press.value);
    widget.onTap!();
  }

  void _handleTapCancel() {
    if (_press.value <= 0) return;
    _press.reverse(from: _press.value);
  }

  @override
  Widget build(BuildContext context) {
    final tile = ChapterModeDock.tileSize;
    final progressWidth = tile * ChapterModeDock.progressBarWidthRatio;
    final enabled = widget.enabled && widget.onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: SizedBox(
        width: tile,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.revealAnimation,
            _deltaFill,
            _returnCheck,
          ]),
          builder: (context, _) {
            final expand = widget.revealAnimation.value.clamp(0.0, 1.0);
            final displayProgress = _displayProgress(expand);
            final checkReveal = _checkReveal(expand);
            final entranceRaw = _entranceRaw(expand);
            final glowPulse = _fillGlow(expand, displayProgress);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: _AnimatedDockProgress(
                    displayValue: displayProgress,
                    color: widget.accentColor,
                    width: progressWidth,
                    entranceRaw: entranceRaw,
                    glowPulse: glowPulse,
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: tile,
                  height: tile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: _handleTapDown,
                          onTapUp: _handleTapUp,
                          onTapCancel: _handleTapCancel,
                          child: _MacIconTile(
                            assetPath: widget.assetPath,
                            size: tile,
                            checkReveal: checkReveal,
                            breathPhase: widget.phase,
                            pressController: _press,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  child: SizedBox(
                    width: tile,
                    height: ChapterModeDock.labelHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        widget.label,
                        maxLines: widget.maxLabelLines,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          color: Colors.white.withValues(alpha: 0.94),
                          shadows: const [
                            Shadow(
                              color: Color(0xCC000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedDockProgress extends StatelessWidget {
  const _AnimatedDockProgress({
    required this.displayValue,
    required this.color,
    required this.width,
    required this.entranceRaw,
    required this.glowPulse,
  });

  final double displayValue;
  final Color color;
  final double width;
  final double entranceRaw;
  final double glowPulse;

  @override
  Widget build(BuildContext context) {
    final entrance = Curves.easeOutCubic.transform(entranceRaw.clamp(0.0, 1.0));
    final slideY = (1 - entrance) * 14;
    final barOpacity = Curves.easeOut.transform(
      (entranceRaw * 2.2).clamp(0.0, 1.0),
    );

    final animatedValue = displayValue.clamp(0.0, 1.0);
    const height = 2.0;
    final fillWidth = animatedValue <= 0
        ? 0.0
        : (width * animatedValue).clamp(width * 0.04, width);

    return Opacity(
      opacity: barOpacity,
      child: Transform.translate(
        offset: Offset(0, slideY),
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.white.withValues(alpha: 0.18)),
                if (fillWidth > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: fillWidth,
                      height: height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.88),
                              color,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(
                                alpha: 0.45 + glowPulse * 0.35,
                              ),
                              blurRadius: 4 + glowPulse * 6,
                              spreadRadius: glowPulse * 0.6,
                            ),
                          ],
                        ),
                        child: fillWidth > 6
                            ? Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: 3,
                                  height: height,
                                  margin: const EdgeInsets.only(right: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.55 + glowPulse * 0.25,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              )
                            : null,
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

class _MacIconTile extends StatefulWidget {
  const _MacIconTile({
    required this.assetPath,
    required this.size,
    required this.breathPhase,
    required this.pressController,
    this.checkReveal = 0,
  });

  final String assetPath;
  final double size;
  final double breathPhase;
  final AnimationController pressController;
  final double checkReveal;

  @override
  State<_MacIconTile> createState() => _MacIconTileState();
}

class _MacIconTileState extends State<_MacIconTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 3200 + (widget.breathPhase * 900).round(),
      ),
    )..value = widget.breathPhase;
    _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = size * 0.22;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final imagePadding = size * 0.04;

    return AnimatedBuilder(
      animation: Listenable.merge([_breath, widget.pressController]),
      builder: (context, _) {
        final breathScale =
            1.0 + math.sin(_breath.value * math.pi * 2) * 0.012;
        final pressT = Curves.easeIn.transform(widget.pressController.value);
        final pressScale = 1.0 - (pressT * 0.13);
        final pressYOffset = pressT * 3.0;
        final iconScale = breathScale * pressScale;

        final checkT = widget.checkReveal.clamp(0.0, 1.0);
        final checkGlow = Curves.easeOut.transform(checkT);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
              if (checkT > 0)
                BoxShadow(
                  color: const Color(0xFFF59E0B)
                      .withValues(alpha: 0.18 + checkGlow * 0.28),
                  blurRadius: 10 + checkGlow * 8,
                  spreadRadius: checkGlow * 1.2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(imagePadding),
                  child: Transform.translate(
                    offset: Offset(0, pressYOffset),
                    child: Transform.scale(
                      scale: iconScale,
                      alignment: Alignment.center,
                      child: Image(
                        image: ChapterModeDock.modeIconProvider(
                          assetPath: widget.assetPath,
                          devicePixelRatio: dpr,
                        ),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        isAntiAlias: true,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                if (checkT > 0)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Transform.scale(
                      scale: 0.35 + checkT * 0.65,
                      child: Transform.rotate(
                        angle: (1 - checkT) * -0.45,
                        child: Opacity(
                          opacity: Curves.easeOut.transform(
                            (checkT * 2.4).clamp(0.0, 1.0),
                          ),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF59E0B),
                              border: Border.all(color: Colors.white, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.45 * checkGlow),
                                  blurRadius: 6 + checkGlow * 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
