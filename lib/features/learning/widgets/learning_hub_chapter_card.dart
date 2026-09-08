import 'dart:async' show unawaited;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../app/scenario_providers.dart';
import '../../../core/constants/labels.dart';
import '../../../core/utils/learning_hub_icon.dart';
import '../../../data/datasources/local/swipe_progress_local_datasource.dart';
import '../../../data/models/learning_hub_chapter.dart';
import '../../../data/models/scenario.dart';
import '../../../data/repositories/sentence_progress_repository.dart';
import '../../../shared/widgets/chapter_hero_image.dart';
import '../../../shared/widgets/flight_progress_bar.dart';
import '../../../shared/widgets/web_safe_backdrop_blur.dart';
import '../../dashboard/dashboard_palette.dart';
import '../../shell/floating_island_nav_bar.dart';
import '../../scenarios/widgets/scenario_bubble_avatar.dart';
import '../../word_swipe/word_swipe_training_screen.dart';
import 'mode_guide_cards.dart';
import 'sentence_group_picker.dart';

enum _ChapterLearningStatus { notStarted, inProgress, completed }

bool _isChapterCompleted({
  required int wordCount,
  required SwipeCategoryProgress? swipeProgress,
  required SentenceCategorySummary? sentenceSummary,
  required List<Scenario> scenarios,
  required bool Function(String scenarioId) isScenarioCompleted,
}) {
  return LearningHubChapterCard.isWordModeComplete(wordCount, swipeProgress) &&
      LearningHubChapterCard.isSentenceModeComplete(sentenceSummary) &&
      LearningHubChapterCard.isScenarioModeComplete(
        scenarios,
        isScenarioCompleted,
      );
}

bool _isChapterInProgress({
  required SwipeCategoryProgress? swipeProgress,
  required SentenceCategorySummary? sentenceSummary,
  required List<Scenario> scenarios,
  required bool Function(String scenarioId) isScenarioCompleted,
}) {
  if (swipeProgress?.played == true) return true;
  if ((sentenceSummary?.readCount ?? 0) > 0) return true;
  if ((sentenceSummary?.attemptedCount ?? 0) > 0) return true;
  return scenarios.any((s) => isScenarioCompleted(s.id));
}

_ChapterLearningStatus _resolveChapterStatus({
  required int wordCount,
  required SwipeCategoryProgress? swipeProgress,
  required SentenceCategorySummary? sentenceSummary,
  required List<Scenario> scenarios,
  required bool Function(String scenarioId) isScenarioCompleted,
}) {
  if (_isChapterCompleted(
    wordCount: wordCount,
    swipeProgress: swipeProgress,
    sentenceSummary: sentenceSummary,
    scenarios: scenarios,
    isScenarioCompleted: isScenarioCompleted,
  )) {
    return _ChapterLearningStatus.completed;
  }
  if (_isChapterInProgress(
    swipeProgress: swipeProgress,
    sentenceSummary: sentenceSummary,
    scenarios: scenarios,
    isScenarioCompleted: isScenarioCompleted,
  )) {
    return _ChapterLearningStatus.inProgress;
  }
  return _ChapterLearningStatus.notStarted;
}

/// 비행 단계별 큰 허브 카드 — ①단어 ②문장 ③시나리오.
class LearningHubChapterCard extends StatefulWidget {
  final LearningHubChapter chapter;
  final String language;
  final int wordCount;
  final SwipeCategoryProgress? swipeProgress;
  final SentenceCategorySummary? sentenceSummary;
  final List<Scenario> scenarios;
  final bool Function(String scenarioId) isScenarioCompleted;
  final VoidCallback? onWordPlay;
  final VoidCallback? onWordReview;
  final bool isExpanded;
  final bool isLast;
  final VoidCallback onExpandRequested;

  /// 짧은 스와이프 스냅 시 증가 — 카드에 바운스 피드백을 트리거한다.
  final int snapToken;

  /// 아코디언 펼침 — 스크롤 애니메이션과 동기화.
  static const expandAnimationDuration = Duration(milliseconds: 680);
  static const expandAnimationCurve = Cubic(0.16, 1.0, 0.3, 1.0);
  static const expandVerticalPadding = 16.0;

  /// 챕터 히어로 표준 — Canva 1920×1280과 동일한 3:2.
  static const fallbackAspectRatio = 3 / 2;
  static const compactOverlap = 16.0;

  static double compactBlockHeight({required bool isLast}) =>
      _compactHeight - (isLast ? 0.0 : compactOverlap);

  static double estimateExpandedBlockHeight(
    double cardWidth, {
    double aspectRatio = fallbackAspectRatio,
  }) {
    return cardWidth / aspectRatio + expandVerticalPadding;
  }

  /// 이미지 로딩 여부 캐시. 실제 원본 비율은 기록하되 카드 레이아웃은
  /// 1920×1280 표준(3:2)으로 고정해 소스별 비율 때문에 높이가 튀지 않는다.
  static final Map<String, double> aspectRatioCache = {};

  const LearningHubChapterCard({
    super.key,
    required this.chapter,
    required this.language,
    required this.wordCount,
    required this.scenarios,
    required this.isScenarioCompleted,
    required this.isExpanded,
    required this.onExpandRequested,
    this.isLast = false,
    this.snapToken = 0,
    this.swipeProgress,
    this.sentenceSummary,
    this.onWordPlay,
    this.onWordReview,
  });

  static const _compactHeight = 88.0;
  static const _outerRadius = 20.0;
  static const _innerImageRadius = 20.0;

  /// 펼쳐진(포커스) 카드 — 존재감 있는 이중 드롭섀도우.
  static final _cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
      blurRadius: 24,
      spreadRadius: 1,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  static final _cardShadowInProgress = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.16),
      blurRadius: 28,
      spreadRadius: 1,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.07),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  /// 압축(스택) 타일 — 촘촘하게 겹쳐도 지저분하지 않도록 더 짧고 또렷한 그림자.
  static final _compactShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.14),
      blurRadius: 14,
      spreadRadius: 0,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 3,
      spreadRadius: 0,
      offset: const Offset(0, 1),
    ),
  ];

  static const _modeBandHeight = 109.0;
  static const _modeBandBottomInset = 12.0;
  static const _modeBandSideInset = 8.0;
  static const _modePanelInnerBottomInset = 10.0;
  static const _heroTextBottomInset = 18.0;
  static const _heroTextAboveModesGap = 14.0;
  static const _imageSlideMax = 10.0;
  static const _modeRevealLift = 108.0;

  static bool isWordModeComplete(
    int wordCount,
    SwipeCategoryProgress? progress,
  ) {
    if (wordCount == 0) return true;
    return progress?.isMastered ?? false;
  }

  static bool isSentenceModeComplete(SentenceCategorySummary? summary) {
    final total = summary?.total ?? 0;
    if (total == 0) return true;
    return summary?.allMastered ?? false;
  }

  static bool isScenarioModeComplete(
    List<Scenario> scenarios,
    bool Function(String scenarioId) isCompleted,
  ) {
    if (scenarios.isEmpty) return true;
    return scenarios.every((s) => isCompleted(s.id));
  }

  static String wordModeProgressSignature({
    required int wordCount,
    required SwipeCategoryProgress? swipeProgress,
    required bool wordComplete,
  }) {
    if (wordCount == 0) return 'empty';
    final known = (swipeProgress?.isMastered ?? false)
        ? wordCount
        : (swipeProgress?.knownCount.clamp(0, wordCount) ?? 0);
    return '${wordComplete ? 1 : 0}:$known/$wordCount';
  }

  static String sentenceModeProgressSignature({
    required SentenceCategorySummary? sentenceSummary,
    required bool sentenceComplete,
  }) {
    final total = sentenceSummary?.total ?? 0;
    if (total == 0) return 'empty';
    final mastered = sentenceSummary?.masteredCount ?? 0;
    return '${sentenceComplete ? 1 : 0}:$mastered/$total';
  }

  static String scenarioModeProgressSignature({
    required List<Scenario> scenarios,
    required bool scenarioComplete,
    required bool Function(String scenarioId) isScenarioCompleted,
  }) {
    if (scenarios.isEmpty) return 'empty';
    final done = scenarios.where((s) => isScenarioCompleted(s.id)).length;
    return '${scenarioComplete ? 1 : 0}:$done/${scenarios.length}';
  }

  @override
  State<LearningHubChapterCard> createState() => _LearningHubChapterCardState();
}

class _LearningHubChapterCardState extends State<LearningHubChapterCard>
    with TickerProviderStateMixin {
  double? _imageAspectRatio;
  ImageStream? _imageAspectStream;
  ImageStreamListener? _imageAspectListener;
  String? _resolvedAspectAsset;
  late final AnimationController _fold;
  late final Animation<double> _foldT;
  late final AnimationController _expandShimmer;
  late final AnimationController _snapPulse;
  late final Animation<double> _snapScale;
  bool _expandShimmerArmed = false;
  int _lastSnapToken = 0;

  static const _fallbackAspectRatio = 3 / 2;

  @override
  void initState() {
    super.initState();
    _fold = AnimationController(
      vsync: this,
      duration: LearningHubChapterCard.expandAnimationDuration,
      reverseDuration: const Duration(milliseconds: 420),
    );
    _foldT = CurvedAnimation(
      parent: _fold,
      curve: LearningHubChapterCard.expandAnimationCurve,
      reverseCurve: const Cubic(0.55, 0.0, 0.45, 1.0),
    );
    _expandShimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _snapPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _snapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.962), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 0.962, end: 1.016), weight: 44),
      TweenSequenceItem(tween: Tween(begin: 1.016, end: 1.0), weight: 28),
    ]).animate(CurvedAnimation(parent: _snapPulse, curve: Curves.easeOutCubic));
    _fold.addListener(_handleExpandShimmer);
    if (widget.isExpanded) _fold.value = 1;
    _resolveImageAspectRatio(_heroAssetPath());
  }

  void _handleExpandShimmer() {
    if (_fold.status == AnimationStatus.reverse ||
        _fold.status == AnimationStatus.dismissed) {
      if (_expandShimmerArmed || _expandShimmer.value > 0) {
        _expandShimmerArmed = false;
        _expandShimmer.reset();
      }
      return;
    }
    if (_fold.status != AnimationStatus.forward) return;
    if (_expandShimmerArmed || _foldT.value < 0.5) return;
    _expandShimmerArmed = true;
    _expandShimmer.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant LearningHubChapterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.chapterImage != widget.chapter.chapterImage ||
        oldWidget.chapter.name != widget.chapter.name) {
      _resolveImageAspectRatio(_heroAssetPath());
    }
    if (oldWidget.isExpanded != widget.isExpanded) {
      if (widget.isExpanded) {
        _fold.forward(from: _fold.value);
      } else {
        _fold.reverse();
      }
    }
    if (widget.snapToken != _lastSnapToken &&
        widget.snapToken > 0 &&
        widget.isExpanded) {
      _lastSnapToken = widget.snapToken;
      _snapPulse.forward(from: 0);
    }
  }

  String _heroAssetPath() {
    return resolveHubChapterIcon(
      chapterImage: widget.chapter.chapterImage,
      category: widget.chapter.name,
    );
  }

  void _resolveImageAspectRatio(String assetPath) {
    final listener = _imageAspectListener;
    final stream = _imageAspectStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _imageAspectListener = null;
    _imageAspectStream = null;

    if (assetPath.isEmpty) {
      if (_imageAspectRatio != _fallbackAspectRatio) {
        setState(() => _imageAspectRatio = _fallbackAspectRatio);
      }
      _resolvedAspectAsset = assetPath;
      return;
    }

    // 다른 카드가 이미 같은 이미지를 실측했다면 캐시로 즉시 반영.
    final cached = LearningHubChapterCard.aspectRatioCache[assetPath];
    if (cached != null && _imageAspectRatio != cached) {
      _imageAspectRatio = cached;
    }

    if (_resolvedAspectAsset == assetPath && _imageAspectRatio != null) {
      return;
    }

    _resolvedAspectAsset = assetPath;
    final imageStream = AssetImage(
      assetPath,
    ).resolve(const ImageConfiguration());
    _imageAspectStream = imageStream;
    _imageAspectListener = ImageStreamListener(
      (ImageInfo info, _) {
        final height = info.image.height.toDouble();
        final ratio = height <= 0
            ? _fallbackAspectRatio
            : info.image.width / height;
        LearningHubChapterCard.aspectRatioCache[assetPath] = ratio;
        if (!mounted) return;
        setState(() => _imageAspectRatio = ratio);
      },
      onError: (_, __) {
        if (!mounted) return;
        setState(() => _imageAspectRatio = _fallbackAspectRatio);
      },
    );
    imageStream.addListener(_imageAspectListener!);
  }

  @override
  void dispose() {
    final listener = _imageAspectListener;
    final stream = _imageAspectStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _fold.removeListener(_handleExpandShimmer);
    _fold.dispose();
    _expandShimmer.dispose();
    _snapPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconAsset = _heroAssetPath();
    final wordComplete = LearningHubChapterCard.isWordModeComplete(
      widget.wordCount,
      widget.swipeProgress,
    );
    final sentenceComplete = LearningHubChapterCard.isSentenceModeComplete(
      widget.sentenceSummary,
    );
    final scenarioComplete = LearningHubChapterCard.isScenarioModeComplete(
      widget.scenarios,
      widget.isScenarioCompleted,
    );
    final allModesCleared =
        wordComplete && sentenceComplete && scenarioComplete;
    final chapterStatus = _resolveChapterStatus(
      wordCount: widget.wordCount,
      swipeProgress: widget.swipeProgress,
      sentenceSummary: widget.sentenceSummary,
      scenarios: widget.scenarios,
      isScenarioCompleted: widget.isScenarioCompleted,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        // 원본이 아직 16:9/4:3이어도 카드 프레임은 항상 3:2.
        // 새 1920×1280 이미지는 무크롭, 기존 이미지는 BoxFit.cover로만 보정한다.
        final expandedHeight = cardWidth / _fallbackAspectRatio;
        const compactHeight = LearningHubChapterCard._compactHeight;

        return AnimatedBuilder(
          animation: Listenable.merge([_foldT, _expandShimmer, _snapPulse]),
          builder: (context, _) {
            final t = _foldT.value.clamp(0.0, 1.0);
            final visualHeight =
                compactHeight + (expandedHeight - compactHeight) * t;
            final overlap = widget.isLast
                ? 0.0
                : LearningHubChapterCard.compactOverlap * (1 - t);
            final layoutHeight = visualHeight - overlap;
            final peel = Curves.easeIn.transform((t / 0.58).clamp(0.0, 1.0));
            final radius = BorderRadius.circular(
              LearningHubChapterCard._outerRadius,
            );
            final shimmerT = Curves.easeInOutCubic.transform(
              _expandShimmer.value,
            );
            final shimmerFade = shimmerT <= 0
                ? 0.0
                : (shimmerT < 0.68
                          ? 1.0
                          : (1 - (shimmerT - 0.68) / 0.32).clamp(0.0, 1.0)) *
                      0.88;

            final cardShadow = t < 0.45
                ? LearningHubChapterCard._compactShadow
                : chapterStatus == _ChapterLearningStatus.inProgress
                ? LearningHubChapterCard._cardShadowInProgress
                : LearningHubChapterCard._cardShadow;
            final cardColor = Color.lerp(
              Colors.white,
              Colors.transparent,
              Curves.easeIn.transform(t),
            )!;
            const rimWidth = 3.2;
            const rimStroke = 2.2;

            return Transform.scale(
              scale: widget.isExpanded ? _snapScale.value : 1.0,
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 8 * t, 0, 8 * t),
                child: SizedBox(
                  width: cardWidth,
                  height: layoutHeight,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: visualHeight,
                    maxHeight: visualHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.94),
                          t,
                        ),
                        borderRadius: radius,
                        boxShadow: [
                          ...cardShadow,
                          if (t > 0.2)
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.95 * t),
                              blurRadius: 0.8,
                              spreadRadius: 2.4 * t,
                            ),
                          if (t > 0.2)
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.35 * t),
                              blurRadius: 10,
                              spreadRadius: 0.6,
                            ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: 0.20 + 0.78 * t,
                          ),
                          width: rimStroke * t.clamp(0.0, 1.0) + 0.01,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(rimWidth * t),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            (LearningHubChapterCard._outerRadius - rimWidth * t)
                                .clamp(10.0, 20.0),
                          ),
                          child: ColoredBox(
                            color: cardColor,
                            child: SizedBox(
                              width: cardWidth,
                              height: visualHeight,
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  if (t > 0.02)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: expandedHeight,
                                      child: _ExpandedChapterVisual(
                                        chapter: widget.chapter,
                                        language: widget.language,
                                        wordCount: widget.wordCount,
                                        swipeProgress: widget.swipeProgress,
                                        sentenceSummary: widget.sentenceSummary,
                                        scenarios: widget.scenarios,
                                        isScenarioCompleted:
                                            widget.isScenarioCompleted,
                                        onWordPlay: widget.onWordPlay,
                                        onWordReview: widget.onWordReview,
                                        iconAsset: iconAsset,
                                        cardWidth: cardWidth,
                                        cardHeight: expandedHeight,
                                        allModesCleared: allModesCleared,
                                        chapterStatus: chapterStatus,
                                      ),
                                    ),
                                  if (peel < 0.999)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: compactHeight,
                                      child: IgnorePointer(
                                        ignoring: t > 0.18,
                                        child: Opacity(
                                          opacity: (1 - peel).clamp(0.0, 1.0),
                                          child: Transform.translate(
                                            offset: Offset(0, -22 * peel),
                                            child: _ChapterCompactTile(
                                              chapter: widget.chapter,
                                              language: widget.language,
                                              iconAsset: iconAsset,
                                              status: chapterStatus,
                                              imageAspectRatio:
                                                  _imageAspectRatio ??
                                                  LearningHubChapterCard
                                                      .fallbackAspectRatio,
                                              onTap: widget.onExpandRequested,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (shimmerFade > 0)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: shimmerFade,
                                          child: CustomPaint(
                                            painter: _ModeShimmerSweepPainter(
                                              progress: shimmerT,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
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
        );
      },
    );
  }
}

/// 펼침 메인 일러스트 — 핸드헬드 카메라 모션 + 고품질 보간.
class _ChapterHeroImageLayer extends StatelessWidget {
  const _ChapterHeroImageLayer({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.motionDx,
    required this.motionDy,
    required this.motionAngle,
  });

  final String assetPath;
  final double width;
  final double height;
  final double motionDx;
  final double motionDy;
  final double motionAngle;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Transform(
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        transform: Matrix4.identity()
          ..translateByDouble(motionDx, motionDy, 0, 1)
          ..rotateZ(motionAngle)
          ..scaleByDouble(1.04, 1.04, 1, 1),
        child: ChapterHeroImage(
          assetPath: assetPath,
          width: width,
          height: height,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          profile: ChapterImageProfile.hero,
        ),
      ),
    );
  }
}

/// 압축(Accordion Collapsed) 상태 — 88px 미니 타일. BackdropFilter/Lottie 없이 가벼움.
class _ChapterCompactTile extends StatelessWidget {
  const _ChapterCompactTile({
    super.key,
    required this.chapter,
    required this.language,
    required this.iconAsset,
    required this.status,
    required this.imageAspectRatio,
    required this.onTap,
  });

  final LearningHubChapter chapter;
  final String language;
  final String iconAsset;
  final _ChapterLearningStatus status;
  final double imageAspectRatio;
  final VoidCallback onTap;

  /// 카드 내부(패딩 제외) 세로 공간에 맞춘 썸네일 높이 — 3:2 등 원본 비율로 가로 확장.
  static const _maxThumbHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final statusMeta = switch (status) {
      _ChapterLearningStatus.notStarted => const (
        fg: Color(0xFF64748B),
        label: '시작 전',
      ),
      _ChapterLearningStatus.inProgress => const (
        fg: Color(0xFF0284C7),
        label: '진행 중',
      ),
      _ChapterLearningStatus.completed => const (
        fg: Color(0xFFD97706),
        label: '완료',
      ),
    };
    final thumbHeight = _maxThumbHeight;
    final thumbWidth = thumbHeight * imageAspectRatio;

    return SizedBox(
      width: double.infinity,
      height: LearningHubChapterCard._compactHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: hubChapterLabel(
                                language,
                                chapter.chapterNo,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: '  ·  ${statusMeta.label}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusMeta.fg,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        chapter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: thumbWidth,
                  height: thumbHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: ChapterHeroImage(
                      assetPath: iconAsset,
                      width: thumbWidth,
                      height: thumbHeight,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      profile: ChapterImageProfile.thumb,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: thumbWidth,
                        height: thumbHeight,
                        color: const Color(0xFF1E293B),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.flight_rounded,
                          size: 22,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 스크롤 flick과 경합하지 않는 탭 레이어 — Listener로 탭만 감지.
class _HeroTapToRevealLayer extends StatefulWidget {
  const _HeroTapToRevealLayer({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HeroTapToRevealLayer> createState() => _HeroTapToRevealLayerState();
}

class _HeroTapToRevealLayerState extends State<_HeroTapToRevealLayer> {
  Offset? _down;
  bool _cancelled = false;

  static const _tapSlop = 18.0;
  static const _verticalSwipeSlop = 6.0;

  void _reset() {
    _down = null;
    _cancelled = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _down = event.position;
        _cancelled = false;
      },
      onPointerMove: (event) {
        if (_down == null || _cancelled) return;
        final delta = event.position - _down!;
        if (delta.dy.abs() > _verticalSwipeSlop || delta.distance > _tapSlop) {
          _cancelled = true;
        }
      },
      onPointerUp: (_) {
        if (!_cancelled && _down != null) {
          widget.onTap();
        }
        _reset();
      },
      onPointerCancel: (_) => _reset(),
      child: const SizedBox.expand(),
    );
  }
}

/// 펼침(Accordion Expanded) 상태 — 기존 3D 일러스트 + 리빌 글래스모피즘 학습 모드 카드.
class _ExpandedChapterVisual extends StatefulWidget {
  const _ExpandedChapterVisual({
    super.key,
    required this.chapter,
    required this.language,
    required this.wordCount,
    required this.swipeProgress,
    required this.sentenceSummary,
    required this.scenarios,
    required this.isScenarioCompleted,
    required this.onWordPlay,
    required this.onWordReview,
    required this.iconAsset,
    required this.cardWidth,
    required this.cardHeight,
    required this.allModesCleared,
    required this.chapterStatus,
  });

  final LearningHubChapter chapter;
  final String language;
  final int wordCount;
  final SwipeCategoryProgress? swipeProgress;
  final SentenceCategorySummary? sentenceSummary;
  final List<Scenario> scenarios;
  final bool Function(String scenarioId) isScenarioCompleted;
  final VoidCallback? onWordPlay;
  final VoidCallback? onWordReview;
  final String iconAsset;
  final double cardWidth;
  final double cardHeight;
  final bool allModesCleared;
  final _ChapterLearningStatus chapterStatus;

  @override
  State<_ExpandedChapterVisual> createState() => _ExpandedChapterVisualState();
}

class _ExpandedChapterVisualState extends State<_ExpandedChapterVisual>
    with TickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _expand;
  late final AnimationController _cameraMotionController;
  bool _modeShimmerArmed = false;
  final List<int?> _modeShimmerDelaysMs = [null, null, null];

  /// 학습 모드 밴드는 오직 사용자의 탭으로만 리빌된다(스크롤 자동 리빌 없음).
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _expand = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _expand.addListener(_handleExpandForShimmer);
    _cameraMotionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7860),
    )..repeat(reverse: true);
    // 기본 세팅: 챕터 no·제목·hook만 보이는 '접힌' 상태로 시작한다.
  }

  ({double dx, double dy, double angle}) _handheldCameraMotion(double t) {
    return (
      dx: math.sin(t * math.pi * 2) * 4.5,
      dy: math.cos(t * math.pi * 1.5) * 3.5,
      angle: math.sin(t * math.pi) * 0.005,
    );
  }

  void _toggleReveal() {
    setState(() => _revealed = !_revealed);
    if (_revealed) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  void _handleExpandForShimmer() {
    if (!mounted) return;
    final modeT = Curves.easeOutCubic.transform(_expand.value);
    if (modeT < 0.12) {
      if (_modeShimmerArmed ||
          _modeShimmerDelaysMs.any((delay) => delay != null)) {
        setState(() {
          _modeShimmerArmed = false;
          _modeShimmerDelaysMs.fillRange(0, 3, null);
        });
      }
      return;
    }
    if (_modeShimmerArmed || modeT < 0.28) return;
    _scheduleRevealShimmers();
  }

  void _scheduleRevealShimmers() {
    if (_modeShimmerArmed) return;
    _modeShimmerArmed = true;
    final rng = math.Random();
    final slotDelays = <int>[
      rng.nextInt(25),
      85 + rng.nextInt(31),
      170 + rng.nextInt(61),
    ]..shuffle(rng);

    setState(() {
      for (var i = 0; i < 3; i++) {
        _modeShimmerDelaysMs[i] = slotDelays[i];
      }
    });
  }

  void _resetModeShimmerState() {
    _modeShimmerArmed = false;
    _modeShimmerDelaysMs.fillRange(0, 3, null);
  }

  void _resetModeIntroIfSignatureChanged(
    int index,
    String oldSignature,
    String newSignature,
  ) {
    if (oldSignature == newSignature) return;
    _resetModeShimmerState();
  }

  List<String> _modeReplayKeys({
    required bool wordComplete,
    required bool sentenceComplete,
    required bool scenarioComplete,
  }) {
    return [
      LearningHubChapterCard.wordModeProgressSignature(
        wordCount: widget.wordCount,
        swipeProgress: widget.swipeProgress,
        wordComplete: wordComplete,
      ),
      LearningHubChapterCard.sentenceModeProgressSignature(
        sentenceSummary: widget.sentenceSummary,
        sentenceComplete: sentenceComplete,
      ),
      LearningHubChapterCard.scenarioModeProgressSignature(
        scenarios: widget.scenarios,
        scenarioComplete: scenarioComplete,
        isScenarioCompleted: widget.isScenarioCompleted,
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant _ExpandedChapterVisual oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldWordComplete = LearningHubChapterCard.isWordModeComplete(
      oldWidget.wordCount,
      oldWidget.swipeProgress,
    );
    final oldSentenceComplete = LearningHubChapterCard.isSentenceModeComplete(
      oldWidget.sentenceSummary,
    );
    final oldScenarioComplete = LearningHubChapterCard.isScenarioModeComplete(
      oldWidget.scenarios,
      oldWidget.isScenarioCompleted,
    );
    final wordComplete = LearningHubChapterCard.isWordModeComplete(
      widget.wordCount,
      widget.swipeProgress,
    );
    final sentenceComplete = LearningHubChapterCard.isSentenceModeComplete(
      widget.sentenceSummary,
    );
    final scenarioComplete = LearningHubChapterCard.isScenarioModeComplete(
      widget.scenarios,
      widget.isScenarioCompleted,
    );

    final oldKeys = _modeReplayKeys(
      wordComplete: oldWordComplete,
      sentenceComplete: oldSentenceComplete,
      scenarioComplete: oldScenarioComplete,
    );
    final newKeys = _modeReplayKeys(
      wordComplete: wordComplete,
      sentenceComplete: sentenceComplete,
      scenarioComplete: scenarioComplete,
    );

    var needsReset = false;
    for (var i = 0; i < 3; i++) {
      if (oldKeys[i] != newKeys[i]) {
        _resetModeIntroIfSignatureChanged(i, oldKeys[i], newKeys[i]);
        needsReset = true;
      }
    }
    if (needsReset) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final modeT = Curves.easeOutCubic.transform(_expand.value);
        if (modeT >= 0.28) _scheduleRevealShimmers();
      });
    }
  }

  @override
  void dispose() {
    _expand.removeListener(_handleExpandForShimmer);
    _expandController.dispose();
    _cameraMotionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hook = widget.chapter.hook.trim();
    final wordComplete = LearningHubChapterCard.isWordModeComplete(
      widget.wordCount,
      widget.swipeProgress,
    );
    final sentenceComplete = LearningHubChapterCard.isSentenceModeComplete(
      widget.sentenceSummary,
    );
    final scenarioComplete = LearningHubChapterCard.isScenarioModeComplete(
      widget.scenarios,
      widget.isScenarioCompleted,
    );
    final modeReplayKeys = _modeReplayKeys(
      wordComplete: wordComplete,
      sentenceComplete: sentenceComplete,
      scenarioComplete: scenarioComplete,
    );
    final innerWidth = widget.cardWidth;
    final innerHeight = widget.cardHeight;

    return AnimatedBuilder(
      animation: Listenable.merge([_expand, _cameraMotionController]),
      builder: (context, _) {
        final t = _expand.value;
        final motion = _handheldCameraMotion(_cameraMotionController.value);
        final imageT = Curves.easeInOut.transform(t);
        final modeT = Curves.easeOutCubic.transform(t);
        final imageSlide = LearningHubChapterCard._imageSlideMax * imageT;
        final modeLift = (1 - modeT) * LearningHubChapterCard._modeRevealLift;
        final heroTextBottomCollapsed =
            LearningHubChapterCard._heroTextBottomInset;
        final heroTextBottomExpanded =
            LearningHubChapterCard._modeBandBottomInset +
            LearningHubChapterCard._modeBandHeight +
            LearningHubChapterCard._heroTextAboveModesGap;
        final heroTextBottom =
            heroTextBottomCollapsed +
            (heroTextBottomExpanded - heroTextBottomCollapsed) * modeT;
        final textCompactT = Curves.easeInOutCubic.transform(
          ((modeT - 0.08) / 0.72).clamp(0.0, 1.0),
        );

        return SizedBox(
          width: innerWidth,
          height: innerHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: innerHeight + LearningHubChapterCard._imageSlideMax,
                child: Transform.translate(
                  offset: Offset(0, -imageSlide),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ChapterHeroImageLayer(
                        assetPath: widget.iconAsset,
                        width: innerWidth,
                        height:
                            innerHeight + LearningHubChapterCard._imageSlideMax,
                        motionDx: motion.dx,
                        motionDy: motion.dy,
                        motionAngle: motion.angle,
                      ),
                      if (widget.allModesCleared && t > 0.45)
                        Positioned(
                          top: 14,
                          left: 0,
                          right: 0,
                          child: Opacity(
                            opacity: ((t - 0.45) / 0.35).clamp(0.0, 1.0),
                            child: const _ChapterAllClearRibbon(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: _ChapterUnifiedBottomScrim(
                    expansion: modeT,
                    cardHeight: innerHeight,
                  ),
                ),
              ),
              if (modeT > 0.001)
                Positioned(
                  left: LearningHubChapterCard._modeBandSideInset,
                  right: LearningHubChapterCard._modeBandSideInset,
                  bottom: LearningHubChapterCard._modeBandBottomInset,
                  child: Transform.translate(
                    offset: Offset(0, modeLift),
                    child: _ChapterModeRow(
                      expandAnimation: _expand,
                      shimmerDelaysMs: _modeShimmerDelaysMs,
                      modeReplayKeys: modeReplayKeys,
                      wordCount: widget.wordCount,
                      swipeProgress: widget.swipeProgress,
                      wordComplete: wordComplete,
                      onWordPlay: widget.onWordPlay,
                      onWordReview: widget.onWordReview,
                      sentenceSummary: widget.sentenceSummary,
                      sentenceComplete: sentenceComplete,
                      language: widget.language,
                      sentenceCategory: widget.chapter.name,
                      sentenceChapterNo: widget.chapter.chapterNo,
                      scenarios: widget.scenarios,
                      scenarioComplete: scenarioComplete,
                      isScenarioCompleted: widget.isScenarioCompleted,
                    ),
                  ),
                ),
              Positioned(
                left: 20,
                right: 20,
                bottom: heroTextBottom,
                child: _ChapterHeroHeaderTexts(
                  language: widget.language,
                  chapterNo: widget.chapter.chapterNo,
                  title: widget.chapter.name,
                  hook: hook,
                  compactProgress: textCompactT,
                  modeRevealProgress: modeT,
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChapterStatusBadge(status: widget.chapterStatus),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
              if (t > 0.04)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: heroTextBottomExpanded + 72,
                  child: _HeroTapToRevealLayer(
                    onTap: () {
                      if (!_expandController.isAnimating) {
                        _toggleReveal();
                      }
                    },
                  ),
                ),
              if (t < 0.04) ...[
                Positioned.fill(
                  child: _HeroTapToRevealLayer(
                    onTap: () {
                      if (!_expandController.isAnimating) {
                        _toggleReveal();
                      }
                    },
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - t / 0.04).clamp(0.0, 1.0),
                      child: const Center(child: _ChapterTapRevealHint()),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 카드 중앙 터치 유도 — Lottie 탭 아이콘 + 안내 문구 (펼쳐진 카드 1개에서만 렌더되므로 가벼움).
class _ChapterTapRevealHint extends StatefulWidget {
  const _ChapterTapRevealHint();

  static const _assetPath = 'assets/lottie/touch1.json';

  @override
  State<_ChapterTapRevealHint> createState() => _ChapterTapRevealHintState();
}

class _ChapterTapRevealHintState extends State<_ChapterTapRevealHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;
  late final Animation<double> _offsetY;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _offsetY = Tween<double>(
      begin: 3.5,
      end: -5.5,
    ).animate(CurvedAnimation(parent: _float, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 64,
          child: AnimatedBuilder(
            animation: _offsetY,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              child: Lottie.asset(
                _ChapterTapRevealHint._assetPath,
                width: 56,
                height: 56,
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
            builder: (context, child) {
              return Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(0, _offsetY.value),
                  child: child,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Touch to start',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _HubChapterGoldTheme {
  static const amberDeep = Color(0xFFD97706);
  static const amber = Color(0xFFF59E0B);
  static const champagne = Color(0xFFFCD34D);
  static const hairline = Color(0xFFFDE68A);
  static const iconGold = Color(0xFFB45309);
}

/// 카드 우측 상단 — 챕터 학습 상태 미니 뱃지.
class _ChapterStatusBadge extends StatefulWidget {
  const _ChapterStatusBadge({required this.status});

  final _ChapterLearningStatus status;

  @override
  State<_ChapterStatusBadge> createState() => _ChapterStatusBadgeState();
}

class _ChapterStatusBadgeState extends State<_ChapterStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseOpacity = Tween<double>(
      begin: 0.72,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = switch (widget.status) {
      _ChapterLearningStatus.notStarted => Colors.black.withValues(alpha: 0.35),
      _ChapterLearningStatus.inProgress => const Color(
        0xFF0284C7,
      ).withValues(alpha: 0.85),
      _ChapterLearningStatus.completed => const Color(0xFFF59E0B),
    };

    final content = switch (widget.status) {
      _ChapterLearningStatus.notStarted => const Text(
        '시작 전',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFCBD5E1),
        ),
      ),
      _ChapterLearningStatus.inProgress => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF38BDF8)),
          SizedBox(width: 5),
          Text(
            '진행 중',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
      _ChapterLearningStatus.completed => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 12, color: Colors.white),
          SizedBox(width: 3),
          Text(
            '완료',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    };

    return AnimatedBuilder(
      animation: _pulseOpacity,
      builder: (context, child) {
        return Opacity(opacity: _pulseOpacity.value, child: child);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: kIsWeb
            ? DecoratedBox(
                decoration: BoxDecoration(color: background),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: content,
                ),
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: background),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: content,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ChapterAllClearRibbon extends StatelessWidget {
  const _ChapterAllClearRibbon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _HubChapterGoldTheme.hairline),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: _HubChapterGoldTheme.amberDeep,
            ),
            SizedBox(width: 6),
            Text(
              'CHAPTER COMPLETE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.55,
                color: DashboardPalette.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이미지 하단 scrim — 3D 이미지가 글래스 칩 뒤로 맑게 비치도록 가볍게 유지.
class _ChapterUnifiedBottomScrim extends StatelessWidget {
  const _ChapterUnifiedBottomScrim({
    required this.expansion,
    required this.cardHeight,
  });

  final double expansion;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final bottomAlpha = 0.82 + 0.1 * expansion.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: bottomAlpha),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _ChapterHeroHeaderTexts extends StatelessWidget {
  final String language;
  final int chapterNo;
  final String title;
  final String hook;
  final double compactProgress;
  final double modeRevealProgress;

  const _ChapterHeroHeaderTexts({
    required this.language,
    required this.chapterNo,
    required this.title,
    this.hook = '',
    this.compactProgress = 0,
    this.modeRevealProgress = 0,
  });

  static double _lerp(double from, double to, double t) =>
      from + (to - from) * t;

  @override
  Widget build(BuildContext context) {
    final catchLine = hook.trim();
    final t = compactProgress.clamp(0.0, 1.0);
    // 모드 리빌 시 hook을 완전히 숨기지 않고 1줄 요약으로 유지한다.
    final hookCompactT = Curves.easeInOutCubic.transform(
      (modeRevealProgress / 0.65).clamp(0.0, 1.0),
    );
    final hookMaxLines = hookCompactT > 0.82 ? 1 : (t > 0.7 ? 2 : 3);

    final chapterSize = _lerp(14, 13, t);
    final titleSize = _lerp(26, 22, t);
    final hookSize = _lerp(14.5, 12.5, t);
    final titleLineHeight = _lerp(1.12, 1.1, t);
    final hookLineHeight = _lerp(1.38, 1.32, t);
    final gapAfterChapter = _lerp(4, 3, t);
    final gapBeforeHook = _lerp(6, 4, t);
    final hookAlpha = _lerp(0.92, 0.86, t);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hubChapterLabel(language, chapterNo),
          style: TextStyle(
            fontSize: chapterSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF38BDF8),
            letterSpacing: _lerp(0.6, 0.5, t),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: _lerp(0.65, 0.72, t)),
                blurRadius: _lerp(8, 9, t),
              ),
            ],
          ),
        ),
        SizedBox(height: gapAfterChapter),
        Text(
          title,
          maxLines: t > 0.82 ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: _lerp(1, 0.96, t)),
            height: titleLineHeight,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: _lerp(0.75, 0.8, t)),
                blurRadius: _lerp(10, 11, t),
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        if (catchLine.isNotEmpty) ...[
          SizedBox(height: gapBeforeHook),
          Text(
            catchLine,
            maxLines: hookMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: hookSize,
              height: hookLineHeight,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(
                alpha: hookAlpha * (1.0 - hookCompactT * 0.12),
              ),
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: _lerp(0.65, 0.72, t)),
                  blurRadius: _lerp(8, 9, t),
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ChapterModeRow extends StatelessWidget {
  final Animation<double> expandAnimation;
  final List<int?> shimmerDelaysMs;
  final List<String> modeReplayKeys;
  final int wordCount;
  final SwipeCategoryProgress? swipeProgress;
  final bool wordComplete;
  final VoidCallback? onWordPlay;
  final VoidCallback? onWordReview;
  final SentenceCategorySummary? sentenceSummary;
  final bool sentenceComplete;
  final String language;
  final String sentenceCategory;
  final int sentenceChapterNo;
  final List<Scenario> scenarios;
  final bool scenarioComplete;
  final bool Function(String scenarioId) isScenarioCompleted;

  const _ChapterModeRow({
    required this.expandAnimation,
    required this.shimmerDelaysMs,
    required this.modeReplayKeys,
    required this.wordCount,
    required this.swipeProgress,
    required this.wordComplete,
    required this.onWordPlay,
    required this.onWordReview,
    required this.sentenceSummary,
    required this.sentenceComplete,
    required this.language,
    required this.sentenceCategory,
    required this.sentenceChapterNo,
    required this.scenarios,
    required this.scenarioComplete,
    required this.isScenarioCompleted,
  });

  double _staggerProgress(int index, double expand) {
    final start = 0.06 + index * 0.11;
    final end = (start + 0.52).clamp(0.0, 1.0);
    if (expand <= start) return 0;
    if (expand >= end) return 1;
    return Curves.easeOutBack.transform((expand - start) / (end - start));
  }

  Widget _staggeredSlot(int index, Widget Function(double reveal) builder) {
    return AnimatedBuilder(
      animation: expandAnimation,
      builder: (context, _) {
        final t = _staggerProgress(index, expandAnimation.value);
        final reveal = t.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 24 * (1 - reveal)),
          child: Transform.scale(
            scale: 0.84 + 0.16 * reveal,
            alignment: Alignment.bottomCenter,
            child: _ModeCardIntroShimmer(
              key: ValueKey('mode-intro-$index-${modeReplayKeys[index]}'),
              shimmerDelayMs: shimmerDelaysMs[index],
              clipRadius: 0,
              child: builder(reveal),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: expandAnimation,
      builder: (context, _) {
        final panelReveal = expandAnimation.value.clamp(0.0, 1.0);
        return SizedBox(
          height: LearningHubChapterCard._modeBandHeight,
          child: _UnifiedModeGlassPanel(
            revealProgress: panelReveal,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: LearningHubChapterCard._modePanelInnerBottomInset,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _staggeredSlot(
                      0,
                      (reveal) => _WordModeCell(
                        revealProgress: reveal,
                        wordCount: wordCount,
                        progress: swipeProgress,
                        completed: wordComplete,
                        onPlay: onWordPlay,
                        onReview: onWordReview,
                        slotAlignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const _ModePanelInsetDivider(),
                  Expanded(
                    child: _staggeredSlot(
                      1,
                      (reveal) => _SentenceModeCell(
                        revealProgress: reveal,
                        summary: sentenceSummary,
                        completed: sentenceComplete,
                        language: language,
                        category: sentenceCategory,
                        chapterNo: sentenceChapterNo,
                        slotAlignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const _ModePanelInsetDivider(),
                  Expanded(
                    child: _staggeredSlot(
                      2,
                      (reveal) => _ScenarioModeCell(
                        revealProgress: reveal,
                        scenarios: scenarios,
                        completed: scenarioComplete,
                        isCompleted: isScenarioCompleted,
                        slotAlignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 모드 카드 — 프로그레스 링 완료 후 1회성 대각선 시머링.
class _ModeCardIntroShimmer extends StatefulWidget {
  final Widget child;
  final int? shimmerDelayMs;
  final double clipRadius;

  const _ModeCardIntroShimmer({
    super.key,
    required this.child,
    required this.shimmerDelayMs,
    this.clipRadius = 16.0,
  });

  @override
  State<_ModeCardIntroShimmer> createState() => _ModeCardIntroShimmerState();
}

class _ModeCardIntroShimmerState extends State<_ModeCardIntroShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant _ModeCardIntroShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shimmerDelayMs == null) {
      _started = false;
      _shimmer.reset();
    } else if (widget.shimmerDelayMs != oldWidget.shimmerDelayMs) {
      _started = false;
      _shimmer.reset();
    }
    _maybeStart();
  }

  void _maybeStart() {
    if (_started || widget.shimmerDelayMs == null) return;
    _started = true;
    final delay = widget.shimmerDelayMs!;
    void runShimmer() {
      if (!mounted) return;
      _shimmer.forward(from: 0);
    }

    if (delay <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => runShimmer());
    } else {
      Future<void>.delayed(Duration(milliseconds: delay), runShimmer);
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.clipRadius),
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) {
                  if (_shimmer.value <= 0) return const SizedBox.shrink();
                  final t = Curves.easeInOutCubic.transform(_shimmer.value);
                  final fade = t < 0.68
                      ? 1.0
                      : (1 - (t - 0.68) / 0.32).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: fade * 0.95,
                    child: CustomPaint(
                      painter: _ModeShimmerSweepPainter(progress: t),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeShimmerSweepPainter extends CustomPainter {
  const _ModeShimmerSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    if (kIsWeb) {
      _paintSimpleSweep(canvas, size);
      return;
    }

    final span = size.width + size.height;
    final band = span * 0.72;
    final travel = span + band * 1.6;
    final sweep = -band * 0.8 + travel * progress;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width * 0.5, size.height * 0.5);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-size.width * 0.5, -size.height * 0.5);

    _drawBand(
      canvas,
      Rect.fromLTWH(sweep, -size.height * 0.35, band, size.height * 1.7),
    );

    canvas.restore();
  }

  void _paintSimpleSweep(Canvas canvas, Size size) {
    final band = size.width * 0.78;
    final sweep = -band * 0.8 + (size.width + band * 1.6) * progress;
    _drawBand(canvas, Rect.fromLTWH(sweep, 0, band, size.height));
  }

  void _drawBand(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..blendMode = BlendMode.softLight
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.48),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ModeShimmerSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 3모드 통합 가로 패널 — Frosted Glass 외곽.
class _UnifiedModeGlassPanel extends StatelessWidget {
  final Widget child;
  final double revealProgress;

  const _UnifiedModeGlassPanel({
    required this.child,
    required this.revealProgress,
  });

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final reveal = revealProgress.clamp(0.0, 1.0);
    final glassReveal = Curves.easeOutCubic.transform(reveal);
    final blurSigma = 12.0 * glassReveal;
    final fillAlpha = 0.15 * glassReveal;
    final borderAlpha = 0.28 * glassReveal;

    final glassFill = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: fillAlpha),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderAlpha),
          width: 1.2,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (blurSigma <= 0.5 || kIsWeb)
            Positioned.fill(child: glassFill)
          else
            Positioned.fill(
              child: WebSafeBackdropBlur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
                child: glassFill,
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// 패널 내부 모드 구분 — 위·아래 여백을 둔 세로선.
class _ModePanelInsetDivider extends StatelessWidget {
  const _ModePanelInsetDivider();

  static const _verticalInset = 14.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _verticalInset),
      child: Container(
        width: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.38),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

/// 통합 패널 내 개별 모드 슬롯 — 완료 오버레이·탭·가이드 버튼.
class _ModePanelSection extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final bool completed;
  final VoidCallback? onTap;
  final Widget? howItWorks;

  const _ModePanelSection({
    required this.child,
    required this.accentColor,
    this.completed = false,
    this.onTap,
    this.howItWorks,
  });

  @override
  Widget build(BuildContext context) {
    final section = Stack(
      fit: StackFit.expand,
      children: [
        if (completed)
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Color(0x14F59E0B))),
          ),
        child,
        if (completed)
          const Positioned(
            top: 5,
            left: 5,
            child: IgnorePointer(child: _ModeClearTrophyBadge()),
          ),
        if (howItWorks != null)
          Positioned(top: 5, right: 5, child: howItWorks!),
      ],
    );

    if (onTap == null) return section;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: accentColor.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: section,
      ),
    );
  }
}

class _ModeClearTrophyBadge extends StatelessWidget {
  const _ModeClearTrophyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(
          color: _HubChapterGoldTheme.hairline.withValues(alpha: 0.55),
          width: 0.9,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.emoji_events_rounded,
        size: 11,
        color: _HubChapterGoldTheme.hairline.withValues(alpha: 0.88),
      ),
    );
  }
}

class _ChampagneSparkleOverlay extends StatefulWidget {
  final bool subtle;
  final bool iconAnchored;

  const _ChampagneSparkleOverlay({
    this.subtle = false,
    this.iconAnchored = false,
  });

  @override
  State<_ChampagneSparkleOverlay> createState() =>
      _ChampagneSparkleOverlayState();
}

class _ChampagneSparkleOverlayState extends State<_ChampagneSparkleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;
  late final double _phase;

  @override
  void initState() {
    super.initState();
    _phase = math.Random().nextDouble();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _twinkle,
      builder: (context, _) {
        return CustomPaint(
          painter: _ChampagneSparklePainter(
            t: (_twinkle.value + _phase) % 1.0,
            subtle: widget.subtle,
            iconAnchored: widget.iconAnchored,
          ),
        );
      },
    );
  }
}

class _SparkleSpec {
  const _SparkleSpec({
    this.x = 0.5,
    this.y = 0.5,
    this.ox = 0,
    this.oy = 0,
    required this.size,
    required this.phase,
    required this.speed,
    this.star = true,
    this.anchored = false,
  });

  final double x;
  final double y;
  final double ox;
  final double oy;
  final double size;
  final double phase;
  final double speed;
  final bool star;
  final bool anchored;
}

class _ChampagneSparklePainter extends CustomPainter {
  const _ChampagneSparklePainter({
    required this.t,
    this.subtle = false,
    this.iconAnchored = false,
  });

  final double t;
  final bool subtle;
  final bool iconAnchored;

  static const _specks = [
    _SparkleSpec(x: 0.50, y: 0.13, size: 9.4, phase: 0.00, speed: 1.00),
    _SparkleSpec(x: 0.27, y: 0.20, size: 8.2, phase: 0.18, speed: 1.10),
    _SparkleSpec(x: 0.75, y: 0.18, size: 9.8, phase: 0.34, speed: 0.90),
    _SparkleSpec(x: 0.16, y: 0.34, size: 7.8, phase: 0.52, speed: 1.14),
    _SparkleSpec(x: 0.84, y: 0.32, size: 8.6, phase: 0.68, speed: 1.06),
    _SparkleSpec(x: 0.30, y: 0.50, size: 9.0, phase: 0.12, speed: 0.86),
    _SparkleSpec(x: 0.70, y: 0.48, size: 8.0, phase: 0.82, speed: 1.02),
    _SparkleSpec(
      x: 0.42,
      y: 0.26,
      size: 5.0,
      phase: 0.44,
      speed: 1.24,
      star: false,
    ),
    _SparkleSpec(
      x: 0.60,
      y: 0.40,
      size: 4.6,
      phase: 0.61,
      speed: 0.94,
      star: false,
    ),
  ];

  static const _iconSpecks = [
    _SparkleSpec(
      ox: 0.02,
      oy: -0.56,
      size: 7.2,
      phase: 0.00,
      speed: 1.00,
      anchored: true,
    ),
    _SparkleSpec(
      ox: 0.46,
      oy: -0.14,
      size: 2.8,
      phase: 0.22,
      speed: 1.08,
      star: false,
      anchored: true,
    ),
    _SparkleSpec(
      ox: -0.44,
      oy: 0.16,
      size: 5.4,
      phase: 0.44,
      speed: 0.94,
      anchored: true,
    ),
    _SparkleSpec(
      ox: 0.24,
      oy: 0.42,
      size: 3.2,
      phase: 0.66,
      speed: 1.12,
      star: false,
      anchored: true,
    ),
    _SparkleSpec(
      ox: -0.20,
      oy: -0.30,
      size: 4.8,
      phase: 0.84,
      speed: 0.88,
      anchored: true,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final specks = iconAnchored
        ? _iconSpecks
        : (subtle ? const <_SparkleSpec>[] : _specks);
    if (specks.isEmpty) return;

    final minIntensity = iconAnchored ? 0.05 : (subtle ? 0.06 : 0.04);
    final sizeScale = iconAnchored ? 1.0 : (subtle ? 0.72 : 1.0);
    final goldAlphaBase = iconAnchored ? 0.07 : (subtle ? 0.08 : 0.18);
    final goldAlphaPeak = iconAnchored ? 0.30 : (subtle ? 0.34 : 0.62);
    final whiteAlphaBase = iconAnchored ? 0.04 : (subtle ? 0.05 : 0.10);
    final whiteAlphaPeak = iconAnchored ? 0.18 : (subtle ? 0.22 : 0.42);
    final iconRadius = math.min(size.width, size.height) * 0.5;

    for (final spec in specks) {
      final wave = math.sin((t * spec.speed + spec.phase) * math.pi * 2);
      final spark = math.max(0.0, wave);
      final intensity = math
          .pow(spark, iconAnchored ? 3.0 : (subtle ? 3.0 : 2.6))
          .toDouble();
      if (intensity < minIntensity) continue;

      final center = spec.anchored
          ? Offset(size.width * 0.5, size.height * 0.5) +
                Offset(spec.ox * iconRadius, spec.oy * iconRadius)
          : Offset(spec.x * size.width, spec.y * size.height);
      final radius = spec.size * sizeScale * (0.5 + 0.35 * intensity);
      final gold = _HubChapterGoldTheme.hairline.withValues(
        alpha: goldAlphaBase + goldAlphaPeak * intensity,
      );
      final white = Colors.white.withValues(
        alpha: whiteAlphaBase + whiteAlphaPeak * intensity,
      );

      if (spec.star) {
        _drawStar(canvas, center, radius, gold);
        _drawStar(canvas, center, radius * 0.38, white);
      } else {
        canvas.drawCircle(center, radius * 0.42, Paint()..color = gold);
        canvas.drawCircle(center, radius * 0.18, Paint()..color = white);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    if (r <= 0.2) return;
    final pinch = r * 0.18;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy - pinch, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + pinch, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy + pinch, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - pinch, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ChampagneSparklePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.subtle != subtle ||
        oldDelegate.iconAnchored != iconAnchored;
  }
}

class _CompletedGoldIcon extends StatelessWidget {
  const _CompletedGoldIcon({
    required this.icon,
    this.size = 21,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: const Color(0xFFB8860B),
      weight: 500,
    );
  }
}

class _ModeShinyIcon extends StatelessWidget {
  const _ModeShinyIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: Color.lerp(color, const Color(0xFF1E293B), 0.22),
      weight: 500,
    );
  }
}

/// 담백한 내부 디스크 — 옅은 tint + 얇은 테두리만.
class _ModeShinyDisc extends StatelessWidget {
  const _ModeShinyDisc({
    required this.size,
    required this.accent,
    required this.gold,
    required this.child,
  });

  final double size;
  final Color accent;
  final bool gold;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fill = gold
        ? const Color(0xFFFFF8E8)
        : Colors.white.withValues(alpha: 0.82);
    final border = gold
        ? const Color(0xFFE8C878)
        : accent.withValues(alpha: 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1),
      ),
      child: Center(child: child),
    );
  }
}

class _ModeGlassIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double progress;
  final double revealProgress;
  final double idlePhase;
  final bool compact;

  const _ModeGlassIcon({
    required this.icon,
    required this.color,
    required this.progress,
    required this.revealProgress,
    this.idlePhase = 0,
    this.compact = false,
  });

  @override
  State<_ModeGlassIcon> createState() => _ModeGlassIconState();
}

class _ModeGlassIconState extends State<_ModeGlassIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring;
  late final Animation<double> _ringCurve;
  bool _started = false;

  double get _outer => widget.compact ? 42.0 : 50.0;
  double get _inner => widget.compact ? 32.0 : 38.0;
  double get _iconSize => widget.compact ? 19.0 : 21.0;
  double get _stroke => widget.compact ? 2.4 : 2.6;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _ringCurve = CurvedAnimation(parent: _ring, curve: Curves.easeOutCubic);
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant _ModeGlassIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTarget = oldWidget.progress.clamp(0.0, 1.0);
    final newTarget = widget.progress.clamp(0.0, 1.0);
    if ((oldTarget - newTarget).abs() > 0.0001) {
      _resetIntroAnimation();
    }
    _maybeStart();
  }

  void _resetIntroAnimation() {
    _started = false;
    _ring.reset();
  }

  void _maybeStart() {
    if (_started || widget.revealProgress < 0.28) return;
    _started = true;
    if (widget.progress.clamp(0.0, 1.0) <= 0.001) {
      return;
    }
    final target = widget.progress.clamp(0.0, 1.0);
    _ring.duration = Duration(
      milliseconds: (420 + 1080 * target).round().clamp(420, 1500),
    );
    _ring.forward(from: 0);
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.progress.clamp(0.0, 1.0);
    final hasProgress = target > 0.001;

    return AnimatedBuilder(
      animation: _ringCurve,
      builder: (context, _) {
        final fillT = _ringCurve.value;
        final displayed = hasProgress ? target * fillT : 0.0;
        final ringFull = hasProgress && displayed >= 0.995;
        final trackColor = widget.color.withValues(alpha: 0.16);
        final ringColor = ringFull
            ? const Color(0xFFD4A843)
            : widget.color.withValues(alpha: 0.88);

        return SizedBox(
          width: _outer,
          height: _outer,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: _outer,
                height: _outer,
                child: CustomPaint(
                  painter: _ModeProgressRingPainter(
                    progress: displayed,
                    color: ringColor,
                    trackColor: trackColor,
                    strokeWidth: _stroke,
                  ),
                ),
              ),
              _ModeShinyDisc(
                size: _inner,
                accent: widget.color,
                gold: ringFull,
                child: ringFull
                    ? _CompletedGoldIcon(
                        icon: widget.icon,
                        size: _iconSize,
                      )
                    : _ModeShinyIcon(
                        icon: widget.icon,
                        color: widget.color,
                        size: _iconSize,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeProgressRingPainter extends CustomPainter {
  const _ModeProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final value = progress.clamp(0.0, 1.0);
    if (value <= 0.001) return;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ModeProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _ModeProgressChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool completed;
  final VoidCallback? onTap;

  const _ModeProgressChip({
    required this.label,
    required this.color,
    this.completed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = completed
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _HubChapterGoldTheme.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _HubChapterGoldTheme.amber.withValues(alpha: 0.42),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: _HubChapterGoldTheme.hairline.withValues(alpha: 0.92),
                ),
                const SizedBox(width: 3),
                Text(
                  '완료',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _HubChapterGoldTheme.hairline.withValues(
                      alpha: 0.92,
                    ),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.38),
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.1,
              ),
            ),
          );

    if (onTap == null) return chip;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }
}

class _ModeVerticalBody extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final Color progressColor;
  final double progress;
  final double revealProgress;
  final String title;
  final String progressLabel;
  final bool completed;
  final VoidCallback? onProgressTap;
  final double idlePhase;
  final bool compact;
  final Alignment slotAlignment;

  const _ModeVerticalBody({
    required this.icon,
    required this.accentColor,
    required this.progressColor,
    required this.progress,
    required this.revealProgress,
    required this.title,
    required this.progressLabel,
    this.completed = false,
    this.onProgressTap,
    this.idlePhase = 0,
    this.compact = false,
    this.slotAlignment = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 0.0 : 4.0;
    final iconGap = compact ? 4.0 : 8.0;
    final labelGap = compact ? 4.0 : 6.0;
    final titleSize = compact ? 11.0 : 12.0;
    final titleLines = compact ? 1 : 2;
    final iconOuter = compact ? 42.0 : 50.0;

    final body = Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: iconOuter,
            height: iconOuter,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _ModeGlassIcon(
                  icon: icon,
                  color: accentColor,
                  progress: progress,
                  revealProgress: revealProgress,
                  idlePhase: idlePhase,
                  compact: compact,
                ),
                if (completed)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _ChampagneSparkleOverlay(
                        subtle: true,
                        iconAnchored: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: iconGap),
          Text(
            title,
            maxLines: titleLines,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: titleSize,
              height: 1.12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          SizedBox(height: labelGap),
          _ModeProgressChip(
            label: progressLabel,
            color: progressColor,
            completed: completed,
            onTap: onProgressTap,
          ),
        ],
      ),
    );

    if (!compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: body,
      );
    }

    return Align(alignment: slotAlignment, child: body);
  }
}

class _WordModeCell extends StatelessWidget {
  static const _accent = Color(0xFFE67E22);
  static const _progressColor = Color(0xFFF59E0B);

  final int wordCount;
  final SwipeCategoryProgress? progress;
  final bool completed;
  final VoidCallback? onPlay;
  final VoidCallback? onReview;
  final double revealProgress;
  final Alignment slotAlignment;

  const _WordModeCell({
    required this.revealProgress,
    required this.wordCount,
    required this.progress,
    required this.completed,
    required this.onPlay,
    required this.onReview,
    this.slotAlignment = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    final unknown = progress?.unknownCount ?? 0;
    final mastered = progress?.isMastered ?? false;
    final known = mastered
        ? wordCount
        : (progress?.knownCount.clamp(0, wordCount) ?? 0);
    final safeTotal = wordCount;
    final ratio = safeTotal <= 0 ? 0.0 : known / safeTotal;
    final canReview = onReview != null && unknown > 0;

    final progressLabel = wordCount == 0
        ? '0/0'
        : canReview
        ? '$known/$safeTotal · 복습'
        : '$known/$safeTotal';

    return _ModePanelSection(
      accentColor: _accent,
      completed: completed,
      onTap: wordCount > 0 ? onPlay : null,
      howItWorks: _ModeHowItWorksButton(
        accent: _accent,
        guideBuilder: (dismiss) => WordSwipeModeGuideCard(onDismiss: dismiss),
      ),
      child: _ModeVerticalBody(
        compact: true,
        icon: Icons.touch_app_rounded,
        accentColor: _accent,
        progressColor: canReview ? const Color(0xFFE53935) : _progressColor,
        progress: completed ? 1 : ratio,
        revealProgress: revealProgress,
        title: '단어 스와이프',
        progressLabel: progressLabel,
        completed: completed,
        onProgressTap: canReview ? onReview : null,
        idlePhase: 0,
        slotAlignment: slotAlignment,
      ),
    );
  }
}

class _SentenceModeCell extends ConsumerStatefulWidget {
  static const _accent = HubTripleModeProgressTrack.sentenceRed;
  static const _progressColor = HubTripleModeProgressTrack.sentencePink;

  final SentenceCategorySummary? summary;
  final bool completed;
  final String language;
  final String category;
  final int chapterNo;
  final double revealProgress;
  final Alignment slotAlignment;

  const _SentenceModeCell({
    required this.revealProgress,
    required this.summary,
    required this.completed,
    required this.language,
    required this.category,
    required this.chapterNo,
    this.slotAlignment = Alignment.bottomCenter,
  });

  @override
  ConsumerState<_SentenceModeCell> createState() => _SentenceModeCellState();
}

class _SentenceModeCellState extends ConsumerState<_SentenceModeCell> {
  final GlobalKey _popupAnchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final total = widget.summary?.total ?? 0;
    final mastered = widget.summary?.masteredCount ?? 0;
    final ratio = total <= 0 ? 0.0 : mastered / total;

    return _ModePanelSection(
      accentColor: _SentenceModeCell._accent,
      completed: widget.completed,
      onTap: total > 0
          ? () => openSentenceTraining(
              context,
              ref: ref,
              language: widget.language,
              category: widget.category,
              chapterNo: widget.chapterNo,
              popupAnchorKey: _popupAnchorKey,
            )
          : null,
      howItWorks: _ModeHowItWorksButton(
        accent: _SentenceModeCell._accent,
        guideBuilder: (dismiss) =>
            BasicSentenceModeGuideCard(onDismiss: dismiss),
      ),
      child: KeyedSubtree(
        key: _popupAnchorKey,
        child: _ModeVerticalBody(
          compact: true,
          icon: Icons.mic_rounded,
          accentColor: _SentenceModeCell._accent,
          progressColor: _SentenceModeCell._progressColor,
          progress: widget.completed ? 1 : ratio,
          revealProgress: widget.revealProgress,
          title: '문장 스피킹',
          progressLabel: total == 0 ? '0/0' : '$mastered/$total',
          completed: widget.completed,
          idlePhase: 2.1,
          slotAlignment: widget.slotAlignment,
        ),
      ),
    );
  }
}

class _ScenarioModeCell extends ConsumerStatefulWidget {
  static const _accent = DashboardPalette.teal;

  final List<Scenario> scenarios;
  final bool completed;
  final bool Function(String scenarioId) isCompleted;
  final double revealProgress;
  final Alignment slotAlignment;

  const _ScenarioModeCell({
    required this.revealProgress,
    required this.scenarios,
    required this.completed,
    required this.isCompleted,
    this.slotAlignment = Alignment.bottomCenter,
  });

  @override
  ConsumerState<_ScenarioModeCell> createState() => _ScenarioModeCellState();
}

class _ScenarioModeCellState extends ConsumerState<_ScenarioModeCell> {
  OverlayEntry? _scenarioPickerEntry;
  final GlobalKey _popupAnchorKey = GlobalKey();

  @override
  void dispose() {
    _removeScenarioPopup();
    super.dispose();
  }

  void _removeScenarioPopup() {
    _scenarioPickerEntry?.remove();
    _scenarioPickerEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.scenarios.length;
    final done = widget.scenarios.where((s) => widget.isCompleted(s.id)).length;
    final ratio = total <= 0 ? 0.0 : done / total;

    return _ModePanelSection(
      accentColor: _ScenarioModeCell._accent,
      completed: widget.completed,
      onTap: total == 0 ? null : () => _showScenarioPopup(context),
      howItWorks: _ModeHowItWorksButton(
        accent: _ScenarioModeCell._accent,
        guideBuilder: (dismiss) => ScenarioModeGuideCard(onDismiss: dismiss),
      ),
      child: KeyedSubtree(
        key: _popupAnchorKey,
        child: _ModeVerticalBody(
          compact: true,
          icon: Icons.chat_bubble_rounded,
          accentColor: _ScenarioModeCell._accent,
          progressColor: const Color(0xFF38BDF8),
          progress: widget.completed ? 1 : ratio,
          revealProgress: widget.revealProgress,
          title: '시나리오 롤플레잉',
          progressLabel: total == 0 ? '0/0' : '$done/$total',
          completed: widget.completed,
          idlePhase: 4.2,
          slotAlignment: widget.slotAlignment,
        ),
      ),
    );
  }

  void _showScenarioPopup(BuildContext context) {
    if (_scenarioPickerEntry != null) {
      _removeScenarioPopup();
      return;
    }

    final resolved = _popupAnchorFor(context, anchorKey: _popupAnchorKey);
    if (resolved == null) return;

    final parent = context;
    final language = widget.scenarios.isEmpty
        ? 'English'
        : widget.scenarios.first.language;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Consumer(
        builder: (context, ref, _) {
          final stats = ref.watch(scenarioProgressProvider).stats;
          return _ScenarioPickerOverlay(
            anchor: resolved.anchor,
            anchorSize: resolved.size,
            scenarios: widget.scenarios,
            isCompleted: widget.isCompleted,
            lastPerformance: (id) => stats.lastPerformance(language, id),
            onDismiss: () {
              if (entry.mounted) entry.remove();
              if (_scenarioPickerEntry == entry) {
                _scenarioPickerEntry = null;
              }
            },
            onSelect: (scenario) {
              if (entry.mounted) entry.remove();
              if (_scenarioPickerEntry == entry) {
                _scenarioPickerEntry = null;
              }
              if (!parent.mounted) return;
              parent.push(
                '/scenarios/train/${Uri.encodeComponent(scenario.id)}',
                extra: scenario,
              );
            },
          );
        },
      ),
    );
    _scenarioPickerEntry = entry;
    resolved.overlay.insert(entry);
  }
}

/// 학습 모드 카드 우상단 `!` — How it works 안내를 근처 오버레이로 띄운다.
class _ModeHowItWorksButton extends StatefulWidget {
  const _ModeHowItWorksButton({
    required this.accent,
    required this.guideBuilder,
  });

  final Color accent;
  final Widget Function(VoidCallback onDismiss) guideBuilder;

  @override
  State<_ModeHowItWorksButton> createState() => _ModeHowItWorksButtonState();
}

class _ModeHowItWorksButtonState extends State<_ModeHowItWorksButton> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  void _showOverlay() {
    if (_entry != null) {
      _removeOverlay();
      return;
    }

    final resolved = _popupAnchorFor(context);
    if (resolved == null) return;
    final origin = resolved.anchor;
    final buttonSize = resolved.size;

    final overlay = resolved.overlay;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return _ModeHowItWorksOverlay(
          anchor: origin,
          anchorSize: buttonSize,
          guide: widget.guideBuilder(() {
            entry.remove();
            if (_entry == entry) _entry = null;
          }),
          onDismiss: () {
            entry.remove();
            if (_entry == entry) _entry = null;
          },
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showOverlay,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.78),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.24),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeHowItWorksOverlay extends StatefulWidget {
  const _ModeHowItWorksOverlay({
    required this.anchor,
    required this.anchorSize,
    required this.guide,
    required this.onDismiss,
  });

  final Offset anchor;
  final Size anchorSize;
  final Widget guide;
  final VoidCallback onDismiss;

  @override
  State<_ModeHowItWorksOverlay> createState() => _ModeHowItWorksOverlayState();
}

class _ModeHowItWorksOverlayState extends State<_ModeHowItWorksOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_entry.status == AnimationStatus.reverse ||
        _entry.status == AnimationStatus.dismissed) {
      return;
    }
    await _entry.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final popupWidth = (size.width - 28).clamp(280.0, 360.0);
    final maxHeight = size.height * 0.62;
    final bottomObstruction =
        pad.bottom + FloatingIslandNavBar.reservedHeight(context);
    final spaceAbove = widget.anchor.dy - pad.top - 12;
    final spaceBelow =
        size.height -
        bottomObstruction -
        (widget.anchor.dy + widget.anchorSize.height) -
        12;
    final nearBottom =
        widget.anchor.dy + widget.anchorSize.height >
        size.height - bottomObstruction - maxHeight * 0.35;
    final showAbove =
        nearBottom || (spaceAbove >= 200 && spaceAbove >= spaceBelow);
    var left = widget.anchor.dx + widget.anchorSize.width / 2 - popupWidth / 2;
    left = left.clamp(14.0, size.width - popupWidth - 14.0);

    final curved = CurvedAnimation(
      parent: _entry,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: FadeTransition(
              opacity: _entry,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            ),
          ),
        ),
        Positioned(
          left: left,
          width: popupWidth,
          top: showAbove
              ? null
              : widget.anchor.dy + widget.anchorSize.height + 8,
          bottom: showAbove ? size.height - widget.anchor.dy + 8 : null,
          child: FadeTransition(
            opacity: _entry,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
              alignment: showAbove
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(child: widget.guide),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 팝업 앵커 — root overlay 좌표계 기준.
/// nested Navigator·Transform 구간에서는 ancestor 변환이 어긋날 수 있어
/// 화면 전역 좌표를 그대로 사용한다.
({Offset anchor, Size size, OverlayState overlay})? _popupAnchorFor(
  BuildContext context, {
  GlobalKey? anchorKey,
}) {
  RenderBox? box;
  final anchorContext = anchorKey?.currentContext;
  if (anchorContext != null) {
    box = anchorContext.findRenderObject() as RenderBox?;
  }
  box ??= context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize || !box.attached) return null;

  // 학습 탭의 분기 Navigator가 아닌 앱 최상위 Navigator의 Overlay에 넣어,
  // MainShell의 플로팅 하단 네비게이션 바보다 위 레이어에 표시한다.
  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  if (overlay == null) return null;
  // root overlay Positioned는 화면 좌표와 동일하므로 globalToLocal 변환은 생략한다.
  final anchor = box.localToGlobal(Offset.zero);
  return (anchor: anchor, size: box.size, overlay: overlay);
}

class _ScenarioPickerOverlay extends StatefulWidget {
  final Offset anchor;
  final Size anchorSize;
  final List<Scenario> scenarios;
  final bool Function(String scenarioId) isCompleted;
  final int? Function(String scenarioId) lastPerformance;
  final VoidCallback onDismiss;
  final ValueChanged<Scenario> onSelect;

  const _ScenarioPickerOverlay({
    required this.anchor,
    required this.anchorSize,
    required this.scenarios,
    required this.isCompleted,
    required this.lastPerformance,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  State<_ScenarioPickerOverlay> createState() => _ScenarioPickerOverlayState();
}

class _ScenarioPickerOverlayState extends State<_ScenarioPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _dimOpacity;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _scale;

  bool? _opensBelow;
  Animation<double>? _slideY;
  Animation<double>? _tiltX;
  Animation<double>? _liftShadow;

  static const _preferredPopupWidth = 292.0;
  static const _screenMargin = 14.0;
  static const _anchorGap = 8.0;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 320),
    );

    _dimOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0, 0.85, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    _panelOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.15, 1, curve: Curves.easeInCubic),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.72,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
    ]).animate(_entry);

    _entry.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ScenarioBubbleAvatar.precacheScenarios(context, widget.scenarios),
      );
    });
  }

  void _ensureDirectionalMotion(bool opensBelow) {
    if (_opensBelow == opensBelow && _slideY != null) return;
    _opensBelow = opensBelow;

    final slideBegin = opensBelow ? -28.0 : 28.0;
    final tiltBegin = opensBelow ? 0.18 : -0.18;
    final motion = CurvedAnimation(
      parent: _entry,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    _slideY = Tween<double>(begin: slideBegin, end: 0).animate(motion);
    _tiltX = Tween<double>(begin: tiltBegin, end: 0).animate(motion);
    _liftShadow = Tween<double>(begin: 0.28, end: 1).animate(
      CurvedAnimation(
        parent: _entry,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_entry.status == AnimationStatus.reverse ||
        _entry.status == AnimationStatus.dismissed) {
      return;
    }
    await _entry.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final pad = media.padding;
    final popupWidth = math.min(
      _preferredPopupWidth,
      math.max(1.0, size.width - _screenMargin * 2),
    );
    final estimatedHeight = math.min(
      widget.scenarios.length * 46.0 + 62,
      math.max(120.0, size.height * 0.52),
    );
    final bottomObstruction =
        pad.bottom + FloatingIslandNavBar.reservedHeight(context);
    final safeTop = pad.top + _screenMargin;
    final safeBottom = math.max(
      safeTop + 120,
      size.height - bottomObstruction - _screenMargin,
    );
    final anchorTop = widget.anchor.dy;
    final anchorBottom = widget.anchor.dy + widget.anchorSize.height;
    final spaceAbove = math.max(0.0, anchorTop - safeTop - _anchorGap);
    final spaceBelow = math.max(0.0, safeBottom - anchorBottom - _anchorGap);
    // 일부만 들어가는 경우 아래로 열면 하단 네비게이션 바에 가려진다.
    // 전체 목록 높이를 확보할 수 있을 때에만 아래로 열고, 그 외에는 위로 연다.
    final showBelow = spaceBelow >= estimatedHeight;
    final availableHeight = math.max(
      120.0,
      math.min(
        estimatedHeight,
        math.min(
          showBelow ? spaceBelow : spaceAbove,
          math.max(120.0, safeBottom - safeTop),
        ),
      ),
    );

    var left = widget.anchor.dx + widget.anchorSize.width / 2 - popupWidth / 2;
    left = left.clamp(
      _screenMargin,
      math.max(_screenMargin, size.width - popupWidth - _screenMargin),
    );

    final popupTop = showBelow
        ? (anchorBottom + _anchorGap).clamp(safeTop, safeBottom - 80)
        : (anchorTop - _anchorGap - availableHeight).clamp(
            safeTop,
            anchorTop - _anchorGap,
          );

    _ensureDirectionalMotion(showBelow);
    final panelAlignment = showBelow
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: FadeTransition(
              opacity: _dimOpacity,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
        ),
        Positioned(
          left: left,
          width: popupWidth,
          top: popupTop,
          child: AnimatedBuilder(
            animation: _entry,
            builder: (context, child) {
              final lift = _liftShadow!.value;
              return Transform(
                alignment: panelAlignment,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.00115)
                  ..translateByDouble(0, _slideY!.value, 0, 1)
                  ..rotateX(_tiltX!.value)
                  ..scaleByDouble(_scale.value, _scale.value, 1, 1),
                child: Opacity(
                  opacity: _panelOpacity.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.06 + 0.14 * lift,
                          ),
                          blurRadius: 10 + 26 * lift,
                          spreadRadius: -1,
                          offset: Offset(0, 5 + 14 * lift),
                        ),
                        BoxShadow(
                          color: DashboardPalette.teal.withValues(
                            alpha: 0.04 + 0.08 * lift,
                          ),
                          blurRadius: 18 + 12 * lift,
                          spreadRadius: -4,
                          offset: Offset(0, 8 + 6 * lift),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight),
                child: SingleChildScrollView(
                  child: _ScenarioPickerPanel(
                    scenarios: widget.scenarios,
                    isCompleted: widget.isCompleted,
                    lastPerformance: widget.lastPerformance,
                    onSelect: widget.onSelect,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioPickerPanel extends StatelessWidget {
  final List<Scenario> scenarios;
  final bool Function(String scenarioId) isCompleted;
  final int? Function(String scenarioId) lastPerformance;
  final ValueChanged<Scenario> onSelect;

  const _ScenarioPickerPanel({
    required this.scenarios,
    required this.isCompleted,
    required this.lastPerformance,
    required this.onSelect,
  });

  static const _dividerColor = Color(0x120F172A);
  static const _dividerInset = 12.0;

  @override
  Widget build(BuildContext context) {
    final panelBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.045),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.55),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            child: Row(
              children: [
                Icon(
                  Icons.forum_rounded,
                  size: 14,
                  color: DashboardPalette.teal.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                const Text(
                  '시나리오 선택',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DashboardPalette.navy,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < scenarios.length; i++) ...[
          _ScenarioPickerRow(
            index: i + 1,
            scenario: scenarios[i],
            completed: isCompleted(scenarios[i].id),
            lastScore: lastPerformance(scenarios[i].id),
            onTap: () => onSelect(scenarios[i]),
          ),
          if (i < scenarios.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: _dividerInset),
              child: Divider(height: 1, thickness: 1, color: _dividerColor),
            ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // 팝업은 Android/Fold에서도 반드시 보이는 독립 표면으로 렌더링.
              // 배경 블러 대신 반투명 채움·림·그림자로 glass 톤을 유지한다.
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: panelBody,
          ),
        ),
      ),
    );
  }
}

class _ScenarioPickerRow extends StatelessWidget {
  final int index;
  final Scenario scenario;
  final bool completed;
  final int? lastScore;
  final VoidCallback onTap;

  const _ScenarioPickerRow({
    required this.index,
    required this.scenario,
    required this.completed,
    required this.lastScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$index. ${scenario.title.isNotEmpty ? scenario.title : scenario.flightStage}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: DashboardPalette.navy,
                ),
              ),
            ),
            if (scenario.isNewContent && !completed)
              const Padding(
                padding: EdgeInsets.only(left: 6, right: 4),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF5252),
                  ),
                ),
              ),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: DashboardPalette.teal.withValues(alpha: 0.88),
                ),
              ),
            if (lastScore != null)
              _ScenarioLastScoreRing(score: lastScore!)
            else
              const _ScenarioLastScoreRing.empty(),
          ],
        ),
      ),
    );
  }
}

/// 최근 performance 기록 — 롤플레이 진척도와 무관.
class _ScenarioLastScoreRing extends StatelessWidget {
  final int? score;

  const _ScenarioLastScoreRing({required this.score});

  const _ScenarioLastScoreRing.empty() : score = null;

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    const stroke = 3.5;
    const track = Color(0xFFE2E8F0);

    if (score == null) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MiniScoreRingPainter(
            ratio: 0,
            fillColors: const [track, track],
            trackColor: track,
            strokeWidth: stroke,
          ),
        ),
      );
    }

    final ratio = (score! / 100).clamp(0.0, 1.0);
    final fillColors = switch (score!) {
      >= 85 => const [Color(0xFF10B981), Color(0xFF06B6D4)],
      >= 55 => const [Color(0xFF0284C7), Color(0xFF38BDF8)],
      _ => const [Color(0xFFF43F5E), Color(0xFFFB7185)],
    };

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _MiniScoreRingPainter(
              ratio: ratio,
              fillColors: fillColors,
              trackColor: track,
              strokeWidth: stroke,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              height: 1,
              color: DashboardPalette.navy.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniScoreRingPainter extends CustomPainter {
  final double ratio;
  final List<Color> fillColors;
  final Color trackColor;
  final double strokeWidth;

  const _MiniScoreRingPainter({
    required this.ratio,
    required this.fillColors,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;
    final fillSweep = fullSweep * ratio.clamp(0.0, 1.0);

    canvas.drawArc(
      rect,
      0,
      fullSweep,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (fillSweep <= 0.001) return;

    final gradient = SweepGradient(
      colors: fillColors,
      startAngle: startAngle,
      endAngle: startAngle + math.max(fillSweep, 0.001),
    );

    canvas.drawArc(
      rect,
      startAngle,
      fillSweep,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniScoreRingPainter oldDelegate) {
    return oldDelegate.ratio != ratio || oldDelegate.fillColors != fillColors;
  }
}

void openWordSwipeFromHub(
  BuildContext context, {
  required String language,
  required String category,
  bool reviewOnly = false,
}) {
  context.push(
    '/scenarios/swipe/play',
    extra: WordSwipeArgs(
      language: language,
      category: category,
      reviewOnly: reviewOnly,
    ),
  );
}

void openSentenceTrainingFromHub(
  BuildContext context, {
  required WidgetRef ref,
  required String language,
  required String category,
  int? chapterNo,
  GlobalKey? popupAnchorKey,
}) {
  openSentenceTraining(
    context,
    ref: ref,
    language: language,
    category: category,
    chapterNo: chapterNo,
    popupAnchorKey: popupAnchorKey,
  );
}
