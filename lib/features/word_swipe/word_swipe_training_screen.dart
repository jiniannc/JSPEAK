import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dictionary_favorite_providers.dart';
import '../../app/learning_tour_providers.dart';
import '../../app/providers.dart';
import '../../app/swipe_progress_providers.dart';
import '../../app/tts_providers.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/language_palette.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../data/models/word_model.dart';
import '../../data/repositories/swipe_progress_repository.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../features/scenarios/widgets/scenario_glass_header.dart';
import 'word_swipe_result_modal.dart';
import 'word_swipe_tour.dart';

/// 라우트 extra / 생성 인자.
class WordSwipeArgs {
  final String language; // English | Japanese | Chinese
  final String category;
  final bool reviewOnly;

  const WordSwipeArgs({
    required this.language,
    required this.category,
    this.reviewOnly = false,
  });
}

/// 틴더 스타일 스와이프 복습 — 카테고리별 단어 선별 → 요약.
class WordSwipeTrainingScreen extends ConsumerStatefulWidget {
  final String language;
  final String category;
  final bool reviewOnly;

  const WordSwipeTrainingScreen({
    super.key,
    required this.language,
    required this.category,
    this.reviewOnly = false,
  });

  @override
  ConsumerState<WordSwipeTrainingScreen> createState() =>
      _WordSwipeTrainingScreenState();
}

class _WordSwipeTrainingScreenState
    extends ConsumerState<WordSwipeTrainingScreen>
    with TickerProviderStateMixin {
  static const _swipeThreshold = 110.0;
  static const _maxTiltRad = 0.22;

  late String _language;
  late String _category;
  late bool _reviewOnly;

  List<WordModel> _deck = [];
  final List<WordModel> _unknownWords = [];
  int _index = 0;
  bool _sessionComplete = false;
  bool _resultPresented = false;
  bool _isLimitedRetry = false;
  bool _revealed = false;
  bool _progressSaved = false;

  Offset _dragOffset = Offset.zero;
  bool _dragging = false;

  late final AnimationController _flyController;
  late final AnimationController _revealController;
  Animation<Offset>? _flyAnim;
  bool _flyingLeft = false;
  bool _panMoved = false;
  bool _tourScheduled = false;

  final WordSwipeTourTargetKeys _tourKeys = WordSwipeTourTargetKeys();

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _category = widget.category;
    _reviewOnly = widget.reviewOnly;
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _commitSwipe(_flyingLeft);
        }
      });
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  bool _bootstrapped = false;

  void _startSession({
    required String language,
    required String category,
    bool reviewOnly = false,
    List<WordModel>? overrideDeck,
  }) {
    final content = ref.read(contentProvider).value;
    if (content == null) return;
    final entries = content.bundle.wordsFor(language, category);
    var deck = [
      for (final entry in entries)
        WordModel.fromVocabularyEntry(
          entry,
          id: SwipeProgressRepository.wordId(
            language: language,
            category: category,
            term: entry.term.trim(),
            meaning: entry.meaning,
          ),
        ),
    ];

    if (overrideDeck != null) {
      deck = List.of(overrideDeck);
    } else if (reviewOnly) {
      final progress =
          ref.read(swipeProgressProvider).stats.forCategory(language, category);
      final unknownIds = progress.unknownWordIds;
      deck = [
        for (final w in deck)
          if (unknownIds.contains(w.id)) w,
      ];
    }

    setState(() {
      _language = language;
      _category = category;
      _reviewOnly = reviewOnly;
      _deck = deck;
      _index = 0;
      _unknownWords.clear();
      _sessionComplete = false;
      _resultPresented = false;
      _isLimitedRetry = overrideDeck != null;
      _revealed = false;
      _progressSaved = false;
      _dragOffset = Offset.zero;
      _dragging = false;
      _revealController.value = 0;
      _flyController.reset();
      _panMoved = false;
    });
    if (_deck.isEmpty) {
      setState(() => _sessionComplete = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentResultModal();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleInitialTour();
      });
    }
  }

  Future<void> _scheduleInitialTour() async {
    if (_tourScheduled || !mounted) return;
    _tourScheduled = true;

    final completed = await ref
        .read(learningTourLocalDataSourceProvider)
        .hasCompletedWordSwipeTour();
    if (!mounted || completed || _deck.isEmpty || _sessionComplete) return;

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _startWordSwipeTour(force: false);
  }

  Future<void> _startWordSwipeTour({required bool force}) async {
    if (!mounted || WordSwipeTour.isShowing) return;
    if (_deck.isEmpty || _sessionComplete) return;

    await WordSwipeTour.show(
      context: context,
      keys: _tourKeys,
      onComplete: () async {
        await ref
            .read(learningTourLocalDataSourceProvider)
            .setCompletedWordSwipeTour(true);
      },
      onSkip: () async {
        await ref
            .read(learningTourLocalDataSourceProvider)
            .setCompletedWordSwipeTour(true);
      },
    );
  }

  Future<void> _presentResultModal() async {
    if (_resultPresented || !mounted) return;
    _resultPresented = true;
    await _persistProgressIfNeeded();
    if (!mounted) return;

    await WordSwipeResultModal.show(
      context: context,
      allWords: List.unmodifiable(_deck),
      unknownWords: List.unmodifiable(_unknownWords),
      category: _category,
      language: _language,
      onRetryLimited: () {
        _resultPresented = false;
        final retryDeck = List<WordModel>.from(_unknownWords);
        if (retryDeck.isEmpty) return;
        _startSession(
          language: _language,
          category: _category,
          reviewOnly: _reviewOnly,
          overrideDeck: retryDeck,
        );
      },
      onRetryFull: () {
        _resultPresented = false;
        _startSession(
          language: _language,
          category: _category,
          reviewOnly: true,
        );
      },
      onExit: () {
        if (mounted) context.pop();
      },
    );

    if (!mounted) return;
    _resultPresented = false;
  }

  Future<void> _persistProgressIfNeeded() async {
    // 중간에 나가면 저장하지 않음 — 미완료 카드가 전부 '안다'로 잡히는 것 방지
    if (_progressSaved || _deck.isEmpty || _index < _deck.length) return;
    _progressSaved = true;
    final allIds = [for (final w in _deck) w.id];
    final unknownIds = [for (final w in _unknownWords) w.id];
    final notifier = ref.read(swipeProgressProvider.notifier);
    if (_isLimitedRetry) {
      await notifier.updateReviewResult(
        language: _language,
        category: _category,
        reviewedWordIds: allIds,
        stillUnknownWordIds: unknownIds,
      );
    } else if (_reviewOnly) {
      await notifier.updateReviewResult(
        language: _language,
        category: _category,
        reviewedWordIds: allIds,
        stillUnknownWordIds: unknownIds,
      );
    } else {
      final content = ref.read(contentProvider).value;
      final fullEntries =
          content?.bundle.wordsFor(_language, _category) ?? const [];
      final fullIds = [
        for (final entry in fullEntries)
          SwipeProgressRepository.wordId(
            language: _language,
            category: _category,
            term: entry.term.trim(),
            meaning: entry.meaning,
          ),
      ];
      await notifier.saveCategoryResult(
        language: _language,
        category: _category,
        allWordIds: fullIds.isNotEmpty ? fullIds : allIds,
        unknownWordIds: unknownIds,
      );
    }
  }

  @override
  void dispose() {
    _flyController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  WordModel? get _current =>
      (_index < _deck.length) ? _deck[_index] : null;

  void _toggleReveal() {
    if (_flyController.isAnimating || _panMoved) return;
    setState(() {
      _revealed = !_revealed;
      if (_revealed) {
        _revealController.forward();
      } else {
        _revealController.reverse();
      }
    });
    HapticFeedback.selectionClick();
  }

  void _onPanStart(DragStartDetails _) {
    if (_flyController.isAnimating || _sessionComplete) return;
    setState(() {
      _dragging = true;
      _panMoved = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging || _flyController.isAnimating) return;
    if (d.delta.distanceSquared > 4) {
      _panMoved = true;
    }
    setState(() {
      _dragOffset += d.delta;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final dx = _dragOffset.dx;
    final vx = d.velocity.pixelsPerSecond.dx;
    final goLeft = dx < -_swipeThreshold || vx < -800;
    final goRight = dx > _swipeThreshold || vx > 800;

    if (goLeft || goRight) {
      _animateFlyOff(left: goLeft);
    } else {
      setState(() => _dragOffset = Offset.zero);
    }
  }

  void _animateFlyOff({required bool left}) {
    _flyingLeft = left;
    final size = MediaQuery.sizeOf(context);
    final end = Offset(
      left ? -size.width * 1.35 : size.width * 1.35,
      _dragOffset.dy * 0.4,
    );
    _flyAnim = Tween<Offset>(begin: _dragOffset, end: end).animate(
      CurvedAnimation(parent: _flyController, curve: Curves.easeInCubic),
    );
    HapticFeedback.lightImpact();
    _flyController.forward(from: 0);
  }

  void _swipeButton({required bool left}) {
    if (_flyController.isAnimating || _current == null || _sessionComplete) {
      return;
    }
    setState(() => _dragOffset = Offset.zero);
    _animateFlyOff(left: left);
  }

  void _commitSwipe(bool left) {
    final word = _current;
    if (word != null && left) {
      _unknownWords.add(word);
    }
    _flyController.reset();
    _flyAnim = null;
    setState(() {
      _dragOffset = Offset.zero;
      _dragging = false;
      _panMoved = false;
      _index += 1;
      _revealed = false;
      _revealController.value = 0;
      if (_index >= _deck.length) {
        _sessionComplete = true;
      }
    });
    if (_index >= _deck.length) {
      _persistProgressIfNeeded();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentResultModal();
      });
    }
  }

  Offset get _cardOffset {
    if (_flyController.isAnimating && _flyAnim != null) {
      return _flyAnim!.value;
    }
    return _dragOffset;
  }

  double get _tilt {
    final w = MediaQuery.sizeOf(context).width;
    return (_cardOffset.dx / w).clamp(-1.0, 1.0) * _maxTiltRad;
  }

  double get _knowOpacity =>
      (_cardOffset.dx / _swipeThreshold).clamp(0.0, 1.0);

  double get _unknownOpacity =>
      (-_cardOffset.dx / _swipeThreshold).clamp(0.0, 1.0);

  Future<void> _exitScreen() async {
    await _persistProgressIfNeeded();
    if (mounted) context.pop();
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.route_rounded),
                  title: const Text('가이드 다시보기'),
                  subtitle: const Text('Word Swipe Tour'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref.read(wordSwipeTourReplaySignalProvider.notifier).request();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app_rounded),
                  title: const Text('학습 종료'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _exitScreen();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(wordSwipeTourReplaySignalProvider, (prev, next) {
      if ((prev ?? 0) < next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startWordSwipeTour(force: true);
        });
      }
    });

    final contentAsync = ref.watch(contentProvider);
    final palette = LanguagePalette.forLanguage(_language);
    final progress = _sessionComplete || _deck.isEmpty
        ? 1.0
        : (_index / _deck.length).clamp(0.0, 1.0);
    final metaLabel = [
      if (_reviewOnly) '리뷰',
      _category,
      languageLabel(_language),
    ].where((e) => e.trim().isNotEmpty).join(' • ');

    const headerReserve = 84.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitScreen();
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: palette.toColorScheme(),
          extensions: [palette],
        ),
        child: DeviceScaffold(
          body: ColoredBox(
            color: DashboardPalette.softGray,
            child: contentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (_) {
                if (!_bootstrapped) {
                  _bootstrapped = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _startSession(
                      language: _language,
                      category: _category,
                      reviewOnly: _reviewOnly,
                    );
                  });
                  return const Center(child: CircularProgressIndicator());
                }

                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: headerReserve),
                      child: AnimatedBuilder(
                        key: ValueKey('swipe_$_category'),
                        animation: Listenable.merge([
                          _flyController,
                          _revealController,
                        ]),
                        builder: (context, _) {
                          return _SwipeSessionView(
                            deck: _deck,
                            index: _index,
                            category: _category,
                            revealed: _revealed,
                            revealProgress: _revealController.value,
                            cardOffset: _cardOffset,
                            tilt: _tilt,
                            knowOpacity: _knowOpacity,
                            unknownOpacity: _unknownOpacity,
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            onTapCard: _toggleReveal,
                            onKnow: () => _swipeButton(left: false),
                            onUnknown: () => _swipeButton(left: true),
                            interactionsEnabled: !_sessionComplete,
                            tourKeys: _tourKeys,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: ScenarioGlassHeader(
                          progress: progress,
                          metaLabel: metaLabel,
                          accentColor: palette.primary,
                          onBack: _exitScreen,
                          onOptions: () => _showOptions(context),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 스와이프 세션
// ─────────────────────────────────────────────

class _SwipeSessionView extends StatelessWidget {
  final List<WordModel> deck;
  final int index;
  final String category;
  final bool revealed;
  final double revealProgress;
  final Offset cardOffset;
  final double tilt;
  final double knowOpacity;
  final double unknownOpacity;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onTapCard;
  final VoidCallback onKnow;
  final VoidCallback onUnknown;
  final bool interactionsEnabled;
  final WordSwipeTourTargetKeys? tourKeys;

  const _SwipeSessionView({
    required this.deck,
    required this.index,
    required this.category,
    required this.revealed,
    required this.revealProgress,
    required this.cardOffset,
    required this.tilt,
    required this.knowOpacity,
    required this.unknownOpacity,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onTapCard,
    required this.onKnow,
    required this.onUnknown,
    this.interactionsEnabled = true,
    this.tourKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            '터치하면 뜻 · 왼쪽은 헷갈려요 · 오른쪽은 외웠어요',
            style: TextStyle(
              fontSize: 12,
              color: DashboardPalette.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 마지막 카드 뒤 또는 세션 종료 후 — 빈 덱 영역 방지
              if (deck.isNotEmpty && index + 1 >= deck.length)
                IgnorePointer(
                  child: _DeckEndPlaceholder(
                    wrappingUp: index >= deck.length,
                  ),
                ),
              // 덱 아래 카드 — 다음 카드가 될 모습 그대로 고정 배치
              // (front가 되었을 때와 완전히 동일한 위치/구성이어야
              //  전환 시 점프 없이 매끄럽게 이어짐)
              if (index + 1 < deck.length)
                IgnorePointer(
                  child: _WordCard(
                    key: ValueKey('deck_${deck[index + 1].id}'),
                    word: deck[index + 1],
                    category: category,
                    wordNumber: index + 2,
                    totalWords: deck.length,
                    revealed: false,
                    revealProgress: 0,
                    knowOpacity: 0,
                    unknownOpacity: 0,
                    showAudioButton: true,
                  ),
                ),
              // 덱 맨 위 카드 — 드래그·날아감만 적용
              if (index < deck.length)
                Transform.translate(
                  offset: cardOffset,
                  child: Transform.rotate(
                    angle: tilt,
                    child: IgnorePointer(
                      ignoring: !interactionsEnabled,
                      child: KeyedSubtree(
                        key: tourKeys?.cardKey,
                        child: GestureDetector(
                          onPanStart: onPanStart,
                          onPanUpdate: onPanUpdate,
                          onPanEnd: onPanEnd,
                          onTap: onTapCard,
                          child: _WordCard(
                            key: ValueKey('deck_${deck[index].id}'),
                            word: deck[index],
                            category: category,
                            wordNumber: index + 1,
                            totalWords: deck.length,
                            revealed: revealed,
                            revealProgress: revealProgress,
                            knowOpacity: knowOpacity,
                            unknownOpacity: unknownOpacity,
                            showAudioButton: true,
                            bookmarkTourKey: tourKeys?.bookmarkKey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundAction(
                key: tourKeys?.unknownButtonKey,
                icon: Icons.close_rounded,
                label: '몰라요',
                color: const Color(0xFFE53935),
                onTap: interactionsEnabled ? onUnknown : null,
              ),
              _RoundAction(
                key: tourKeys?.knowButtonKey,
                icon: Icons.favorite_rounded,
                label: '알아요',
                color: DashboardPalette.teal,
                onTap: interactionsEnabled ? onKnow : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: color, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 단어 카드
// ─────────────────────────────────────────────

class _WordCard extends ConsumerWidget {
  final WordModel word;
  final String category;
  final int wordNumber;
  final int totalWords;
  final bool revealed;
  final double revealProgress;
  final double knowOpacity;
  final double unknownOpacity;
  final bool showAudioButton;
  final Key? bookmarkTourKey;

  const _WordCard({
    super.key,
    required this.word,
    required this.category,
    required this.wordNumber,
    required this.totalWords,
    required this.revealed,
    required this.revealProgress,
    required this.knowOpacity,
    required this.unknownOpacity,
    this.showAudioButton = false,
    this.bookmarkTourKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final cardW = math.min(size.width - 40, 420.0);
    final cardH = math.min(size.height * 0.52, 480.0);
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final entry = word.toVocabularyEntry(category: category);
    final isBookmarked = ref
        .watch(dictionaryFavoritesResolvedProvider)
        .contains(entry.storageFavoriteKey);

    return Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: DashboardPalette.teal.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    DashboardPalette.softGray.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DashboardPalette.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$wordNumber / $totalWords',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: DashboardPalette.tealDeep,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (showAudioButton)
                      _SwipeWordBookmarkToggle(
                        key: bookmarkTourKey ??
                            ValueKey(entry.storageFavoriteKey),
                        isBookmarked: isBookmarked,
                        onToggle: () async {
                          final added = await ref
                              .read(dictionaryFavoritesProvider.notifier)
                              .toggleWord(entry);
                          if (context.mounted) {
                            showDictionaryFavoriteSnackBar(
                              context,
                              added: added,
                            );
                          }
                        },
                      ),
                  ],
                ),
                const Spacer(flex: 2),
                Text(
                  word.word,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: DashboardPalette.navy,
                  ),
                ),
                if (word.showsPronunciation &&
                    (word.pronunciation?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  Text(
                    word.pronunciation!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: DashboardPalette.textMuted,
                    ),
                  ),
                ],
                if (showAudioButton) ...[
                  const SizedBox(height: 16),
                  _CardAudioButton(
                    isSpeaking: isSpeaking,
                    onTap: () {
                      ref.read(ttsSpeakingProvider.notifier).speakWord(
                            word: word.word,
                            language: WordModel.sheetLanguage(word.language),
                          );
                    },
                  ),
                ],
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: Curves.easeOutCubic.transform(revealProgress),
                    child: Opacity(
                      opacity: revealProgress.clamp(0.0, 1.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          Container(
                            width: 48,
                            height: 3,
                            decoration: BoxDecoration(
                              color: DashboardPalette.borderLight,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            word.meaning,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: DashboardPalette.tealDeep,
                            ),
                          ),
                          if (word.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              word.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: DashboardPalette.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                Text(
                  revealed ? '다시 터치하면 가려져요' : '터치하면 뜻이 보여요',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DashboardPalette.textMuted.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 28,
            right: 24,
            child: IgnorePointer(
              ignoring: knowOpacity < 0.05,
              child: Opacity(
                opacity: knowOpacity,
                child: Transform.rotate(
                  angle: -0.18,
                  child: _SwipeStamp(
                    label: '알아요',
                    sub: '외웠어요',
                    color: DashboardPalette.teal,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 28,
            left: 24,
            child: IgnorePointer(
              ignoring: unknownOpacity < 0.05,
              child: Opacity(
                opacity: unknownOpacity,
                child: Transform.rotate(
                  angle: 0.18,
                  child: _SwipeStamp(
                    label: '몰라요',
                    sub: '헷갈려요',
                    color: const Color(0xFFE53935),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeWordBookmarkToggle extends StatefulWidget {
  final bool isBookmarked;
  final Future<void> Function() onToggle;

  const _SwipeWordBookmarkToggle({
    super.key,
    required this.isBookmarked,
    required this.onToggle,
  });

  @override
  State<_SwipeWordBookmarkToggle> createState() =>
      _SwipeWordBookmarkToggleState();
}

class _SwipeWordBookmarkToggleState extends State<_SwipeWordBookmarkToggle> {
  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    await widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF59E0B);
    const muted = Color(0xFF94A3B8);

    final icon = widget.isBookmarked
        ? Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40F59E0B),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 20,
              color: gold,
            ),
          )
        : Icon(
            Icons.star_outline_rounded,
            size: 20,
            color: muted.withValues(alpha: 0.5),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(child: icon),
      ),
    );
  }
}

class _CardAudioButton extends StatelessWidget {
  final bool isSpeaking;
  final VoidCallback onTap;

  const _CardAudioButton({
    required this.isSpeaking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DashboardPalette.teal.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isSpeaking ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSpeaking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DashboardPalette.tealDeep,
                  ),
                )
              else
                const Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                  color: DashboardPalette.tealDeep,
                ),
              const SizedBox(width: 6),
              Text(
                isSpeaking ? '재생 중' : '발음 듣기',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DashboardPalette.tealDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;

  const _SwipeStamp({
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// 마지막 카드 뒤·스와이프 직후 빈 덱 영역 — 텍스트 없이 깊이감·모션만으로 처리.
class _DeckEndPlaceholder extends StatefulWidget {
  final bool wrappingUp;

  const _DeckEndPlaceholder({this.wrappingUp = false});

  @override
  State<_DeckEndPlaceholder> createState() => _DeckEndPlaceholderState();
}

class _DeckEndPlaceholderState extends State<_DeckEndPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _DeckEndPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wrappingUp != widget.wrappingUp) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.wrappingUp) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cardW = math.min(size.width - 40, 420.0);
    final cardH = math.min(size.height * 0.52, 480.0);

    return Transform.translate(
      offset: widget.wrappingUp ? Offset.zero : const Offset(0, 10),
      child: Transform.scale(
        scale: widget.wrappingUp ? 1.0 : 0.96,
        child: SizedBox(
          width: cardW,
          height: cardH,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse = Curves.easeInOutSine.transform(
                _pulseController.value,
              );
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: widget.wrappingUp ? 0.10 : 0.05,
                      ),
                      blurRadius: widget.wrappingUp ? 26 : 14,
                      offset: Offset(0, widget.wrappingUp ? 12 : 8),
                    ),
                    if (widget.wrappingUp)
                      BoxShadow(
                        color: DashboardPalette.teal.withValues(
                          alpha: 0.10 + pulse * 0.12,
                        ),
                        blurRadius: 28 + pulse * 10,
                        spreadRadius: pulse * 2,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: widget.wrappingUp ? 14 : 8,
                      sigmaY: widget.wrappingUp ? 14 : 8,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: widget.wrappingUp
                                  ? [
                                      Colors.white.withValues(alpha: 0.88),
                                      DashboardPalette.softGray
                                          .withValues(alpha: 0.55),
                                      DashboardPalette.teal.withValues(
                                        alpha: 0.06 + pulse * 0.06,
                                      ),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.42),
                                      DashboardPalette.softGray
                                          .withValues(alpha: 0.28),
                                    ],
                              stops: widget.wrappingUp
                                  ? const [0.0, 0.55, 1.0]
                                  : null,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: widget.wrappingUp ? 0.72 : 0.55,
                              ),
                              width: 1.2,
                            ),
                          ),
                        ),
                        if (!widget.wrappingUp) ...[
                          Positioned(
                            left: 14,
                            right: 14,
                            top: 18,
                            bottom: 18,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: DashboardPalette.teal
                                      .withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: CustomPaint(
                              painter: _DeckBackPatternPainter(opacity: 0.55),
                            ),
                          ),
                        ] else ...[
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.72,
                                  colors: [
                                    DashboardPalette.teal.withValues(
                                      alpha: 0.10 + pulse * 0.10,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DeckWrapShimmerPainter(progress: pulse),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 36),
                              child: _WrapPulseDots(progress: pulse),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 덱 바닥 — 은은한 대각 그리드 + 동심원 (카드 뒷면 느낌).
class _DeckBackPatternPainter extends CustomPainter {
  final double opacity;

  const _DeckBackPatternPainter({this.opacity = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = DashboardPalette.teal.withValues(alpha: 0.045 * opacity)
      ..strokeWidth = 1;

    const step = 22.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }

    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        size.width * 0.11 * i,
        Paint()
          ..color = DashboardPalette.tealDeep.withValues(
            alpha: (0.035 / i) * opacity,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DeckBackPatternPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

/// 완료 직후 — 중앙을 가로지르는 얇은 시안 쉬머.
class _DeckWrapShimmerPainter extends CustomPainter {
  final double progress;

  const _DeckWrapShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (0.38 + progress * 0.18);
    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        DashboardPalette.teal.withValues(alpha: 0.0),
        const Color(0xFF06B6D4).withValues(alpha: 0.22),
        DashboardPalette.teal.withValues(alpha: 0.0),
        Colors.transparent,
      ],
      stops: const [0, 0.35, 0.5, 0.65, 1],
    );
    final rect = Rect.fromLTWH(0, y - 1, size.width, 2);
    canvas.drawRect(
      rect,
      Paint()..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _DeckWrapShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 완료 직후 — 3점 순차 펄스 (로딩 텍스트 대체).
class _WrapPulseDots extends StatelessWidget {
  final double progress;

  const _WrapPulseDots({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final phase = ((progress + index * 0.28) % 1.0);
        final scale = 0.55 + Curves.easeOut.transform(phase) * 0.45;
        final alpha = 0.25 + Curves.easeOut.transform(phase) * 0.55;
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 7),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DashboardPalette.tealDeep.withValues(alpha: alpha),
                boxShadow: [
                  BoxShadow(
                    color: DashboardPalette.teal.withValues(alpha: alpha * 0.45),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
