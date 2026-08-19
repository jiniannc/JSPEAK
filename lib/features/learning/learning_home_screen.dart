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
import '../../core/utils/learning_hub_icon.dart';
import '../../data/models/content_bundle.dart';
import '../../data/models/learning_hub_chapter.dart';
import '../../data/repositories/sentence_progress_repository.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../shell/floating_island_nav_bar.dart';
import '../../shared/widgets/cascade_entrance.dart';
import 'widgets/learning_hub_chapter_card.dart';
import 'widgets/learning_hub_guide_strip.dart';

/// 학습 탭 메인 — 비행 단계별 허브 카드에서 3모드로 진입.
class LearningHomeScreen extends ConsumerStatefulWidget {
  const LearningHomeScreen({super.key});

  @override
  ConsumerState<LearningHomeScreen> createState() =>
      _LearningHomeScreenState();
}

class _LearningHomeScreenState extends ConsumerState<LearningHomeScreen> {
  bool _guideVisible = false;
  int? _expandedChapterNo;
  bool _initialFocusPending = true;
  bool _initialFocusQueued = false;
  bool _suppressScrollExpand = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<int, GlobalKey> _chapterKeys = {};
  String? _lastLanguage;
  String? _precachedImagesLanguage;
  bool _compactScrollMode = false;
  double _scrollDragStartOffset = 0;
  bool _isUserDragScroll = false;
  double _scrollPeakVelocity = 0;
  double _scrollSampleOffset = 0;
  DateTime? _scrollSampleTime;
  List<int> _orderedChapterNos = const [];
  int _chapterSnapToken = 0;

  static const _longDragThresholdPx = 96.0;
  static const _shortSwipeVelocityPx = 220.0;
  /// 펼친 카드가 뷰포트 세로 중앙에 오도록 (ensureVisible 클램프로 첫·끝 챕터는 자연스럽게).
  static const _chapterFocusAlignment = 0.5;
  static const _chapterSnapDuration = Duration(milliseconds: 380);
  static const _chapterSwipeSnapDuration = Duration(milliseconds: 480);
  static const _chapterExpandDuration = Duration(milliseconds: 680);
  static const _chapterRecenterDuration = Duration(milliseconds: 300);

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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int chapterNo) =>
      _chapterKeys.putIfAbsent(chapterNo, () => GlobalKey());

  void _scrollChapterIntoView(
    int? chapterNo, {
    double alignment = _chapterFocusAlignment,
    Duration duration = Duration.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    if (chapterNo == null) return;
    final ctx = _chapterKeys[chapterNo]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
  }

  void _centerExpandedChapter(
    int chapterNo, {
    Duration duration = _chapterSnapDuration,
    Curve curve = Curves.easeOutCubic,
  }) {
    if (_expandedChapterNo != chapterNo) return;
    _scrollChapterIntoView(
      chapterNo,
      alignment: _chapterFocusAlignment,
      duration: duration,
      curve: curve,
    );
  }

  /// 아코디언 펼침(680ms) 후 최종 높이 기준으로 한 번 더 센터링.
  void _schedulePostExpandRecenter(int chapterNo) {
    Future.delayed(
      _chapterExpandDuration + const Duration(milliseconds: 48),
      () {
        if (!mounted || _expandedChapterNo != chapterNo) return;
        _centerExpandedChapter(
          chapterNo,
          duration: _chapterRecenterDuration,
        );
      },
    );
  }

  /// 스크롤 종료 시 판정 — flick(속도 우선) vs 느린 긴 드래그(컴팩트).
  void _onUserScrollEnd(ScrollEndNotification notification) {
    if (_suppressScrollExpand || _initialFocusPending) return;

    final dragDetails = notification.dragDetails;
    final pointerVelocity =
        dragDetails?.velocity.pixelsPerSecond.dy ?? 0;
    final dragDelta = _scrollController.offset - _scrollDragStartOffset;

    final flickSpeed =
        math.max(pointerVelocity.abs(), _scrollPeakVelocity.abs());

    // 빠른 flick → 이동 거리와 무관하게 챕터 스냅
    if (flickSpeed >= _shortSwipeVelocityPx) {
      // offset 증가(손가락 위) = 다음 챕터
      final direction = _scrollPeakVelocity.abs() >= pointerVelocity.abs()
          ? (_scrollPeakVelocity > 0 ? 1 : -1)
          : (pointerVelocity > 0 ? -1 : 1);
      _jumpToAdjacentChapter(direction);
      return;
    }

    // 느린 긴 드래그 → 컴팩트 리스트
    if (dragDelta.abs() >= _longDragThresholdPx && !_compactScrollMode) {
      setState(() {
        _compactScrollMode = true;
        _expandedChapterNo = null;
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _scrollDragStartOffset = _scrollController.offset;
      _isUserDragScroll = true;
      _scrollPeakVelocity = 0;
      _scrollSampleOffset = _scrollController.offset;
      _scrollSampleTime = null;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final now = DateTime.now();
      final offset = notification.metrics.pixels;
      final sampleTime = _scrollSampleTime;
      if (sampleTime != null) {
        final dtMs = now.difference(sampleTime).inMilliseconds;
        if (dtMs > 0) {
          final v = (offset - _scrollSampleOffset) / dtMs * 1000;
          if (v.abs() > _scrollPeakVelocity.abs()) {
            _scrollPeakVelocity = v;
          }
        }
      }
      _scrollSampleTime = now;
      _scrollSampleOffset = offset;
    } else if (notification is ScrollEndNotification && _isUserDragScroll) {
      _isUserDragScroll = false;
      _scrollSampleTime = null;
      _onUserScrollEnd(notification);
    }
    return false;
  }

  int? _nearestChapterToViewport() {
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.attached) return null;

    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final focusY = viewportTop + viewportBox.size.height * 0.42;

    int? nearestChapterNo;
    var nearestDistance = double.infinity;
    for (final entry in _chapterKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final center = top + box.size.height / 2;
      final distance = (center - focusY).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestChapterNo = entry.key;
      }
    }
    return nearestChapterNo;
  }

  void _focusChapter(
    int chapterNo, {
    bool animateScroll = true,
    bool swipeSnap = false,
  }) {
    setState(() {
      _compactScrollMode = false;
      _expandedChapterNo = chapterNo;
      if (swipeSnap) _chapterSnapToken++;
    });
    if (swipeSnap) {
      HapticFeedback.lightImpact();
    }
    if (!animateScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _expandedChapterNo != chapterNo) return;
        _centerExpandedChapter(chapterNo, duration: Duration.zero);
        _schedulePostExpandRecenter(chapterNo);
      });
      return;
    }
    _suppressScrollExpand = true;
    final snapDuration =
        swipeSnap ? _chapterSwipeSnapDuration : _chapterSnapDuration;
    final snapCurve = swipeSnap ? Curves.easeOutBack : Curves.easeOutCubic;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _expandedChapterNo != chapterNo) return;
      _centerExpandedChapter(
        chapterNo,
        duration: snapDuration,
        curve: snapCurve,
      );
      _schedulePostExpandRecenter(chapterNo);
      Future.delayed(
        snapDuration + const Duration(milliseconds: 40),
        () {
          if (mounted) _suppressScrollExpand = false;
        },
      );
    });
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

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.offset);
    }

    _focusChapter(_orderedChapterNos[nextIndex], swipeSnap: true);
  }

  void _handleExpandedChapterHeroReady(int chapterNo) {
    if (_expandedChapterNo != chapterNo) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _expandedChapterNo != chapterNo) return;
      _centerExpandedChapter(chapterNo);
      _schedulePostExpandRecenter(chapterNo);
      if (_initialFocusPending) {
        _initialFocusPending = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _suppressScrollExpand = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Active5Layout.of(context);
    final inset = metrics.pagePadding.left;
    final language = ref.watch(learningHubLanguageProvider);
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
        if (_lastLanguage != language) {
          // 언어가 바뀌면 챕터 번호가 재사용되므로 이전 위치 측정용 키를 비운다.
          _lastLanguage = language;
          _chapterKeys.clear();
          _expandedChapterNo = null;
          _initialFocusPending = true;
          _initialFocusQueued = false;
          _precachedImagesLanguage = null;
          _compactScrollMode = false;
        }
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

            return NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: ListView(
                key: _viewportKey,
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
            inset,
                  0,
            inset,
                  28 + FloatingIslandNavBar.scrollBottomPadding(context),
                ),
                children: [
            CascadeEntrance(
              child: _LearningHubSectionHeader(
                totalChapters: chapters.length,
                completedChapters: completedChapters,
                onGuideTap: () => setState(() => _guideVisible = !_guideVisible),
              ),
            ),
            if (_guideVisible) ...[
              const SizedBox(height: 10),
              LearningHubGuideStrip(
                onDismiss: () => setState(() => _guideVisible = false),
              ),
            ],
            const SizedBox(height: 8),
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
                  key: _keyFor(chapters[i].chapterNo),
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
                          chapters[i].chapterNo == expandedChapterNo
                      ? _chapterSnapToken
                      : 0,
                  onHeroReady: expandedChapterNo != null &&
                          chapters[i].chapterNo == expandedChapterNo
                      ? () => _handleExpandedChapterHeroReady(
                            chapters[i].chapterNo,
                          )
                      : null,
                  onExpandRequested: () =>
                      _focusChapter(chapters[i].chapterNo),
                ),
              ],
                ],
              ),
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
  final VoidCallback onGuideTap;

  const _LearningHubSectionHeader({
    required this.totalChapters,
    required this.completedChapters,
    required this.onGuideTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '기내대화 커리큘럼',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$completedChapters/$totalChapters 완료',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0284C7),
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onGuideTap,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '학습 가이드',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
  final VoidCallback? onHeroReady;
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
    this.onHeroReady,
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHeroImage());
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
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
    if (widget.isExpanded) {
      widget.onHeroReady?.call();
    }
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

    return FadeTransition(
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
    );
  }
}
