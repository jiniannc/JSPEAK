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
import '../../../data/models/sentence.dart';
import '../../../data/repositories/sentence_progress_repository.dart';
import '../../../shared/widgets/chapter_hero_image.dart';
import '../../../shared/widgets/flight_progress_bar.dart';
import '../../../shared/widgets/web_safe_backdrop_blur.dart';
import '../../dashboard/dashboard_palette.dart';
import '../../shell/floating_island_nav_bar.dart';
import '../../scenarios/widgets/scenario_bubble_avatar.dart';
import '../../word_swipe/word_swipe_training_screen.dart';
import 'learning_hub_chapter_mode_dock.dart';
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
  final List<Sentence> sentences;
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
  static const expandVerticalPadding = 12.0;

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
    this.sentences = const [],
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

  /// 압축(스택) 타일 — 겹쳐도 카드 경계가 읽히도록 짧고 또렷한 드롭섀도.
  static final _compactShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.19),
      blurRadius: 18,
      spreadRadius: 0.5,
      offset: const Offset(0, 7),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.09),
      blurRadius: 5,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 1.5,
      spreadRadius: 0,
      offset: const Offset(0, 1),
    ),
  ];

  static const _dockBottomInset = ChapterModeDock.bottomInset;
  static const _dockRightInset = ChapterModeDock.rightInset;
  static const _dockReservedWidth = ChapterModeDock.reservedWidth;
  static const _heroTextBottomInset = ChapterModeDock.bottomInset;
  static const _imageSlideMax = 10.0;

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

  static const fallbackAspectRatio = 3 / 2;
  static const _fallbackAspectRatio = fallbackAspectRatio;

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

            final isCompactStack = t < 0.45;
            final cardShadow = isCompactStack
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
            // 스택(접힘) 상태 — 흰 림·글로우 없이 드롭섀도만으로 경계 표현.
            final frameHold = isCompactStack
                ? 0.0
                : (1 - Curves.easeOut.transform(t)).clamp(0.0, 1.0);
            final innerRadius = (LearningHubChapterCard._outerRadius -
                    rimWidth * frameHold)
                .clamp(10.0, 20.0);

            return Transform.scale(
              scale: widget.isExpanded ? _snapScale.value : 1.0,
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 8 * t, 0, 4 * t),
                child: SizedBox(
                  width: cardWidth,
                  height: layoutHeight,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: visualHeight,
                    maxHeight: visualHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94 * frameHold),
                        borderRadius: radius,
                        boxShadow: [
                          ...cardShadow,
                          if (frameHold > 0.08) ...[
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.95 * frameHold),
                              blurRadius: 0.8,
                              spreadRadius: 2.4 * frameHold,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.35 * frameHold),
                              blurRadius: 10,
                              spreadRadius: 0.6,
                            ),
                          ],
                        ],
                        border: frameHold > 0.02
                            ? Border.all(
                                color: Colors.white.withValues(
                                  alpha: 0.20 + 0.78 * frameHold,
                                ),
                                width: rimStroke * frameHold + 0.01,
                              )
                            : null,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(rimWidth * frameHold),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(innerRadius),
                          child: ColoredBox(
                            color: cardColor,
                            child: SizedBox(
                              width: cardWidth,
                              height: visualHeight,
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  if (widget.isExpanded || t > 0)
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
                                        sentences: widget.sentences,
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
          ..translate(motionDx, motionDy)
          ..rotateZ(motionAngle)
          ..scale(1.04, 1.04, 1.0),
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
    required this.sentences,
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
  final List<Sentence> sentences;
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

  /// 학습 모드 도크는 오직 사용자의 탭으로만 리빌된다(스크롤 자동 리빌 없음).
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _expand = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
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

  @override
  void dispose() {
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
    final innerWidth = widget.cardWidth;
    final innerHeight = widget.cardHeight;

    return AnimatedBuilder(
      animation: Listenable.merge([_expand, _cameraMotionController]),
      builder: (context, _) {
        final t = _expand.value;
        final motion = _handheldCameraMotion(_cameraMotionController.value);
        final imageT = Curves.easeInOut.transform(t);
        final imageSlide = LearningHubChapterCard._imageSlideMax * imageT;
        final textCompactT = Curves.easeInOutCubic.transform(
          ((t - 0.08) / 0.72).clamp(0.0, 1.0),
        );
        final dockOpen = t > 0.04;
        final contentBottom = dockOpen
            ? ChapterModeDock.bottomInset
            : LearningHubChapterCard._heroTextBottomInset;

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
                    expansion: t,
                    cardHeight: innerHeight,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: dockOpen
                    ? LearningHubChapterCard._dockRightInset
                    : 20,
                bottom: contentBottom,
                child: dockOpen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _ChapterHeroHeaderTexts(
                              language: widget.language,
                              chapterNo: widget.chapter.chapterNo,
                              title: widget.chapter.name,
                              hook: hook,
                              compactProgress: textCompactT,
                              modeRevealProgress: t,
                            ),
                          ),
                          ChapterModeDock(
                            revealAnimation: _expand,
                            wordCount: widget.wordCount,
                            swipeProgress: widget.swipeProgress,
                            wordComplete: wordComplete,
                            sentenceSummary: widget.sentenceSummary,
                            sentences: widget.sentences,
                            sentenceComplete: sentenceComplete,
                            language: widget.language,
                            sentenceCategory: widget.chapter.name,
                            sentenceChapterNo: widget.chapter.chapterNo,
                            scenarios: widget.scenarios,
                            scenarioComplete: scenarioComplete,
                            isScenarioCompleted: widget.isScenarioCompleted,
                          ),
                        ],
                      )
                    : _ChapterHeroHeaderTexts(
                        language: widget.language,
                        chapterNo: widget.chapter.chapterNo,
                        title: widget.chapter.name,
                        hook: hook,
                        compactProgress: textCompactT,
                        modeRevealProgress: t,
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
                  bottom: contentBottom + 88,
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
  static const hairline = Color(0xFFFDE68A);
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
    final dockOpen = modeRevealProgress > 0.04;
    final hookMaxLines = dockOpen ? 3 : (t > 0.7 ? 2 : 3);

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
              color: Colors.white.withValues(alpha: hookAlpha),
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
