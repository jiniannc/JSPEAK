import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dictionary_favorite_providers.dart';
import '../../../app/dictionary_providers.dart';
import '../../../app/providers.dart';
import '../../../app/search_providers.dart';
import '../../../app/shell_providers.dart';
import '../../../core/services/audio_prefetch.dart';
import '../../../core/theme/language_palette.dart';
import '../../../data/models/sentence.dart';
import '../../../data/models/vocabulary_entry.dart';
import '../../dashboard/dashboard_palette.dart';
import '../dictionary_item_kind_colors.dart';
import '../dictionary_quick_search_logic.dart';
import '../../shell/floating_island_nav_bar.dart';
import 'dictionary_glass_search_result_card.dart';
import 'dictionary_glass_word_search_result_card.dart';
import 'dictionary_hero_search.dart';
import 'dictionary_search_feedback.dart';
import 'bookmark_vault_modal.dart';

/// 기내사전 Dynamic Live Search — 한 화면 내 실시간 검색 UX.
class DictionaryLiveSearchView extends ConsumerStatefulWidget {
  final String language;
  final LanguagePalette palette;
  final double inset;
  final List<DictionaryFavoriteItem> favorites;
  final ValueChanged<DictionaryFavoriteItem> onFavoriteTap;

  const DictionaryLiveSearchView({
    super.key,
    required this.language,
    required this.palette,
    required this.inset,
    required this.favorites,
    required this.onFavoriteTap,
  });

  @override
  ConsumerState<DictionaryLiveSearchView> createState() =>
      _DictionaryLiveSearchViewState();
}

class _DictionaryLiveSearchViewState extends ConsumerState<DictionaryLiveSearchView>
    with TickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 420);
  static const _entryDuration = Duration(milliseconds: 1200);
  static const _debounceDuration = Duration(milliseconds: 80);
  static const _loaderRevealDelay = Duration(milliseconds: 140);
  static const _diceRollDuration = Duration(milliseconds: 720);

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final AnimationController _entryController;
  late final AnimationController _diceController;
  late final Animation<double> _searchFade;
  late final Animation<double> _searchScale;
  late final List<Animation<double>> _chipAnimations;
  late final Animation<double> _titleTyping;
  late final Animation<double> _favoritesSlide;
  late final Animation<double> _favoritesFade;
  late final Animation<double> _diceSpin;
  late final math.Random _chipRandom;
  Timer? _debounceTimer;
  Timer? _loaderRevealTimer;
  String _debouncedQuery = '';
  bool _searchEngaged = false;
  bool _showLoader = false;
  List<String> _chipLabels = const [];
  int _chipGeneration = 0;
  bool _hasChipCandidates = false;

  bool get _isLiveActive => _searchEngaged;

  bool get _isQueryPending {
    final raw = _controller.text.trim();
    final debounced = _debouncedQuery.trim();
    return raw.isNotEmpty && raw != debounced;
  }

  @override
  void initState() {
    super.initState();
    _chipRandom = math.Random();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    _entryController = AnimationController(
      vsync: this,
      duration: _entryDuration,
    );
    _diceController = AnimationController(
      vsync: this,
      duration: _diceRollDuration,
    );
    _diceSpin = CurvedAnimation(
      parent: _diceController,
      curve: Curves.easeInOutCubic,
    );
    _searchFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _searchScale = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
    );
    _chipAnimations = List.generate(kDictionaryQuickSearchChipCount, (index) {
      final start = 0.2 + index * (70 / _entryDuration.inMilliseconds);
      final end = math.min(start + 0.15, 0.6);
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
    _titleTyping = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.35, 0.85, curve: Curves.linear),
    );
    _favoritesSlide = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic),
    );
    _favoritesFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 0.8, curve: Curves.easeOut),
    );
    _scheduleEntryAnimation();
  }

  @override
  void didUpdateWidget(covariant DictionaryLiveSearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _refreshQuickSearchChips(initial: true);
    }
  }

  void _refreshQuickSearchChips({bool initial = false, bool reroll = false}) {
    final words = ref.read(contentProvider).value?.bundle.words ?? const [];
    final hasCandidates = words.any(
      (w) => w.language == widget.language && w.important,
    );
    final nextLabels = pickRandomImportantChipLabels(
      words: words,
      language: widget.language,
      random: _chipRandom,
      exclude: reroll ? _chipLabels : null,
    );

    setState(() {
      _hasChipCandidates = hasCandidates;
      _chipLabels = nextLabels;
      if (reroll) _chipGeneration++;
    });

    if (initial && _chipGeneration == 0 && nextLabels.isNotEmpty) {
      // 첫 진입 애니메이션은 기존 entry controller가 처리.
    }
  }

  Future<void> _rollQuickSearchChips() async {
    if (_diceController.isAnimating) return;
    await _diceController.forward(from: 0);
    if (!mounted) return;
    _diceController.value = 0;
    _refreshQuickSearchChips(reroll: true);
  }

  void _replayEntryAnimation() {
    if (!mounted || _searchEngaged) return;
    _entryController.reset();
    _scheduleEntryAnimation();
  }

  /// Web hot restart 직후 CanvasKit 초기화와 겹치지 않도록 2프레임 뒤 시작.
  void _scheduleEntryAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _searchEngaged) return;
        _entryController.forward(from: 0);
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _loaderRevealTimer?.cancel();
    _entryController.dispose();
    _diceController.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleLoaderReveal() {
    _loaderRevealTimer?.cancel();
    if (!_isQueryPending) {
      if (_showLoader) setState(() => _showLoader = false);
      return;
    }
    _loaderRevealTimer = Timer(_loaderRevealDelay, () {
      if (!mounted) return;
      if (_isQueryPending) setState(() => _showLoader = true);
    });
  }

  void _finishQueryUpdate(String next) {
    _loaderRevealTimer?.cancel();
    setState(() {
      _debouncedQuery = next;
      _showLoader = false;
    });
    ref.read(searchProvider.notifier).setQuery(next);
    _prefetchSearchAudio(next);
  }

  void _prefetchSearchAudio(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    final bundle = ref.read(contentProvider).value?.bundle;
    if (bundle == null) return;
    AudioPrefetch.sentences(
      bundle.search(q, language: widget.language),
      limit: 12,
    );
  }

  void _enterSearch() {
    if (!_searchEngaged) {
      setState(() => _searchEngaged = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      // Web에서 확장 직후 포커스가 한 프레임 늦는 경우 보정
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    });
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _scheduleLoaderReveal();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      _finishQueryUpdate(_controller.text);
    });
    setState(() {});
  }

  void _applyQuery(String value) {
    _debounceTimer?.cancel();
    _loaderRevealTimer?.cancel();
    _controller.text = value;
    _debouncedQuery = value;
    _showLoader = false;
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      ref.read(searchProvider.notifier).submitSearch(trimmed);
    } else {
      ref.read(searchProvider.notifier).setQuery('');
    }
    _prefetchSearchAudio(value);
    setState(() => _searchEngaged = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _loaderRevealTimer?.cancel();
    _controller.clear();
    _debouncedQuery = '';
    _showLoader = false;
    ref.read(searchProvider.notifier).setQuery('');
    _focusNode.unfocus();
    setState(() => _searchEngaged = false);
  }

  List<Sentence> _sentenceResults() {
    final q = _debouncedQuery.trim();
    if (q.isEmpty) return const [];
    final bundle = ref.watch(contentProvider).value?.bundle;
    if (bundle == null) return const [];
    return bundle.search(q, language: widget.language);
  }

  List<VocabularyEntry> _wordResults() {
    final q = _debouncedQuery.trim();
    if (q.isEmpty) return const [];
    final bundle = ref.watch(contentProvider).value?.bundle;
    if (bundle == null) return const [];
    return bundle.searchWords(q, language: widget.language);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(shellTabIndexProvider, (previous, next) {
      if (next == kDictionaryShellTabIndex && previous != kDictionaryShellTabIndex) {
        _replayEntryAnimation();
      }
    });

    ref.listen(dictionaryHomeResetProvider, (previous, next) {
      if (previous != next) _clearSearch();
    });
    ref.listen(dictionarySearchJumpProvider, (previous, next) {
      if (next != null && next.isNotEmpty && next != previous) {
        _applyQuery(next);
        ref.read(dictionarySearchJumpProvider.notifier).clear();
      }
    });

    ref.listen(contentProvider, (previous, next) {
      final prevWords = previous?.value?.bundle.words;
      final nextWords = next.value?.bundle.words;
      if (prevWords == nextWords) return;
      _refreshQuickSearchChips(initial: _chipLabels.isEmpty);
    });

    if (_chipLabels.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshQuickSearchChips(initial: true);
      });
    }

    final active = _isLiveActive;
    final wordResults = _wordResults();
    final sentenceResults = _sentenceResults();
    final contentLoading = ref.watch(contentProvider).isLoading;
    final rawQuery = _controller.text.trim();
    final showLoading = rawQuery.isNotEmpty &&
        (contentLoading || (_showLoader && _isQueryPending));
    final screenW = MediaQuery.sizeOf(context).width;
    final compactW = (screenW * 0.72).clamp(220.0, 340.0);
    final contentInset = active ? 12.0 : widget.inset;
    final fullW = screenW - contentInset * 2;

    final searchBar = _LiveSearchPillBar(
      key: const ValueKey('dictionary-live-search-bar'),
      palette: widget.palette,
      controller: _controller,
      focusNode: _focusNode,
      expanded: active,
      compactWidth: compactW,
      fullWidth: fullW,
      onClear: _clearSearch,
      onExpandTap: _enterSearch,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const compactBarHeight = 46.0;
              const expandedBarHeight = 52.0;
              final barHeight = active ? expandedBarHeight : compactBarHeight;

              const titleBlockHeight = 52.0;
              const heroGap = 32.0;
              const chipsGap = 36.0;
              const chipsBlockHeight = 44.0;
              const favoritesReserve = 76.0;
              final navBottom =
                  FloatingIslandNavBar.scrollBottomPadding(context) + 8;

              final heroMaxHeight = active
                  ? constraints.maxHeight
                  : math.max(
                      0.0,
                      constraints.maxHeight - favoritesReserve - navBottom,
                    );
              final heroContentHeight = titleBlockHeight +
                  heroGap +
                  compactBarHeight +
                  chipsGap +
                  chipsBlockHeight;
              final heroTopPadding = active
                  ? 0.0
                  : math.max(16.0, (heroMaxHeight - heroContentHeight) / 2);
              final searchTop = active
                  ? 4.0
                  : heroTopPadding + titleBlockHeight + heroGap;
              final searchInset = active ? contentInset : widget.inset;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: active
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              contentInset,
                              expandedBarHeight + 8,
                              contentInset,
                              0,
                            ),
                            child: _buildResultsList(
                              wordResults: wordResults,
                              sentenceResults: sentenceResults,
                              showLoading: showLoading,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: widget.inset,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: heroMaxHeight,
                                    ),
                                    child: Column(
                                      children: [
                                        SizedBox(height: heroTopPadding),
                                        DictionaryHeroTitleAnimated(
                                          progress: _titleTyping,
                                          language: widget.language,
                                          palette: widget.palette,
                                          onDiceTap: _hasChipCandidates
                                              ? _rollQuickSearchChips
                                              : null,
                                          diceSpin: _diceSpin,
                                        ),
                                        SizedBox(height: heroGap),
                                        SizedBox(height: compactBarHeight),
                                        SizedBox(height: chipsGap),
                                        DictionaryQuickSearchChips(
                                          tags: _chipLabels,
                                          generation: _chipGeneration,
                                          palette: widget.palette,
                                          onTagSelected: _applyQuery,
                                          entryAnimations: _chipGeneration == 0
                                              ? _chipAnimations
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: widget.inset,
                                ),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.4),
                                    end: Offset.zero,
                                  ).animate(_favoritesSlide),
                                  child: FadeTransition(
                                    opacity: _favoritesFade,
                                    child: _CompactFavoritesPanel(
                                      inset: 0,
                                      palette: widget.palette,
                                      favorites: widget.favorites,
                                      onFavoriteTap: widget.onFavoriteTap,
                                      onViewAll: () =>
                                          BookmarkVaultModal.show(context),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: navBottom),
                            ],
                          ),
                  ),
                  AnimatedPositioned(
                    duration: _transitionDuration,
                    curve: Curves.easeInOutCubic,
                    top: searchTop,
                    left: searchInset,
                    right: searchInset,
                    height: barHeight,
                    child: active
                        ? searchBar
                        : AnimatedBuilder(
                            animation: _entryController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _searchFade.value,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.diagonal3Values(
                                    _searchScale.value,
                                    1.0,
                                    1.0,
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: searchBar,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList({
    required List<VocabularyEntry> wordResults,
    required List<Sentence> sentenceResults,
    required bool showLoading,
  }) {
    final query = _debouncedQuery.trim();
    final rawQuery = _controller.text.trim();

    Widget content;
    Key contentKey;

    if (rawQuery.isEmpty) {
      final search = ref.watch(searchProvider);
      contentKey = ValueKey('search-history-${search.recentQueries.length}');
      content = _DictionarySearchHistoryPanel(
        palette: widget.palette,
        recentQueries: search.recentQueries,
        loading: search.historyLoading,
        onQueryTap: _applyQuery,
        onRemove: (q) => ref.read(searchProvider.notifier).removeRecent(q),
        onClear: () => ref.read(searchProvider.notifier).clearRecent(),
      );
    } else if (showLoading) {
      contentKey = ValueKey('search-loading-$rawQuery');
      content = DictionaryGlassSearchLoader(
        accent: widget.palette.primary,
      );
    } else if (query.isEmpty) {
      contentKey = ValueKey('search-pending-$rawQuery');
      content = DictionaryGlassSearchLoader(
        accent: widget.palette.primary,
      );
    } else if (wordResults.isEmpty && sentenceResults.isEmpty) {
      contentKey = ValueKey('search-empty-$query');
      content = Center(
        child: Text(
          '검색 결과가 없습니다',
          style: TextStyle(
            fontSize: 13,
            color: DashboardPalette.textMuted.withValues(alpha: 0.8),
          ),
        ),
      );
    } else {
      contentKey = ValueKey('search-results-$query');
      content = _AdaptiveSplitSearchResults(
        wordResults: wordResults,
        sentenceResults: sentenceResults,
        query: query,
        accent: widget.palette.primary,
      );
    }

    return DictionarySearchResultsTransition(
      child: KeyedSubtree(
        key: contentKey,
        child: content,
      ),
    );
  }
}

/// 콘텐츠 양에 따라 단어·문장 영역 높이를 동적으로 배분.
class _AdaptiveSplitSearchResults extends StatelessWidget {
  static const _sectionHeaderHeight = 34.0;
  static const _dividerBlockHeight = 13.0;
  static const _wordGridColumns = 3;
  static const _wordGridRowHeight = 124.0;
  static const _wordGridSpacing = 6.0;

  final List<VocabularyEntry> wordResults;
  final List<Sentence> sentenceResults;
  final String query;
  final Color accent;

  const _AdaptiveSplitSearchResults({
    required this.wordResults,
    required this.sentenceResults,
    required this.query,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final hasWords = wordResults.isNotEmpty;
    final hasSentences = sentenceResults.isNotEmpty;

    if (hasWords && !hasSentences) {
      return _WordGridSearchSection(
        query: query,
        count: wordResults.length,
        accent: accent,
        entries: wordResults,
      );
    }

    if (hasSentences && !hasWords) {
      return _SearchResultsSection(
        label: '문장',
        query: query,
        count: sentenceResults.length,
        accent: accent,
        itemCount: sentenceResults.length,
        itemBuilder: (context, index) => DictionaryGlassSearchResultCard(
          sentence: sentenceResults[index],
          query: query,
          accent: accent,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;

        final wordNeed = _estimateWordSectionHeight(wordResults, maxW);
        final sentenceNeed =
            _estimateSentenceSectionHeight(sentenceResults, maxW);
        final totalNeed = wordNeed + sentenceNeed + _dividerBlockHeight;

        // 한쪽만 짧을 때만 intrinsic — 양쪽 다 길면 항상 5:5
        final shortSectionCap = maxH * 0.36;
        final wordIsShort = wordNeed <= shortSectionCap;
        final sentenceIsShort = sentenceNeed <= shortSectionCap;
        final bothAreLong = !wordIsShort && !sentenceIsShort;

        final divider = Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(
            height: 1,
            thickness: 1,
            color: accent.withValues(alpha: 0.08),
          ),
        );

        Widget wordSection({required bool intrinsic}) =>
            _WordGridSearchSection(
              query: query,
              count: wordResults.length,
              accent: accent,
              entries: wordResults,
              intrinsic: intrinsic,
            );

        Widget sentenceSection({required bool intrinsic}) =>
            _SearchResultsSection(
              label: '문장',
              query: query,
              count: sentenceResults.length,
              accent: accent,
              intrinsic: intrinsic,
              itemCount: sentenceResults.length,
              itemBuilder: (context, index) =>
                  DictionaryGlassSearchResultCard(
                sentence: sentenceResults[index],
                query: query,
                accent: accent,
              ),
            );

        // 전체가 화면에 들어가면 — 카드 끝 지점까지만 (여백 없음)
        if (totalNeed <= maxH) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              wordSection(intrinsic: true),
              divider,
              sentenceSection(intrinsic: true),
            ],
          );
        }

        // 양쪽 모두 길면 — 5:5 분할 + 각각 스크롤
        if (bothAreLong) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: wordSection(intrinsic: false)),
              divider,
              Expanded(child: sentenceSection(intrinsic: false)),
            ],
          );
        }

        // 한쪽만 짧으면 — 짧은 쪽 intrinsic, 긴 쪽 Expanded + 스크롤
        if (wordIsShort && !sentenceIsShort) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              wordSection(intrinsic: true),
              divider,
              Expanded(child: sentenceSection(intrinsic: false)),
            ],
          );
        }

        if (sentenceIsShort && !wordIsShort) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: wordSection(intrinsic: false)),
              divider,
              sentenceSection(intrinsic: true),
            ],
          );
        }

        // 추정 오차 등 엣지 — 5:5 폴백
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: wordSection(intrinsic: false)),
            divider,
            Expanded(child: sentenceSection(intrinsic: false)),
          ],
        );
      },
    );
  }

  static double _estimateWordSectionHeight(
    List<VocabularyEntry> words,
    double maxWidth,
  ) {
    if (words.isEmpty) return 0;
    final rows = (words.length / _wordGridColumns).ceil();
    final gridHeight = rows * _wordGridRowHeight +
        math.max(0, rows - 1) * _wordGridSpacing;
    return _sectionHeaderHeight + gridHeight + 4;
  }

  static double _estimateSentenceSectionHeight(
    List<Sentence> sentences,
    double maxWidth,
  ) {
    // 본문 + 우측 액션 레일 + 패딩
    final textWidth = math.max(maxWidth - 108, 160.0);
    final charsPerLine = _charsPerLine(textWidth);

    var cards = 0.0;
    for (final sentence in sentences) {
      var lines = 0;
      lines += (sentence.sentence.length / charsPerLine).ceil();
      if (sentence.pronunciation.trim().isNotEmpty) lines += 1;
      if (sentence.korean.trim().isNotEmpty) {
        lines += (sentence.korean.length / charsPerLine).ceil();
      }
      final textH = lines * 20.0;
      var cardH = 18.0; // 카드 패딩
      if (sentence.category.trim().isNotEmpty) cardH += 22;
      cardH += textH;
      cardH += 22; // 학습모드 링크
      cardH += 8; // 카드 간격
      cards += cardH;
    }
    return _sectionHeaderHeight + cards;
  }

  static double _charsPerLine(double width) {
    return (width / 8.4).floorToDouble().clamp(22.0, 96.0);
  }
}

/// 단어 검색 결과 — 3열 그리드.
class _WordGridSearchSection extends StatelessWidget {
  final String query;
  final int count;
  final Color accent;
  final List<VocabularyEntry> entries;
  final bool intrinsic;

  const _WordGridSearchSection({
    required this.query,
    required this.count,
    required this.accent,
    required this.entries,
    this.intrinsic = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        intrinsic ? 4.0 : 4 + FloatingIslandNavBar.scrollBottomPadding(context);

    final grid = GridView.builder(
      shrinkWrap: intrinsic,
      padding: EdgeInsets.only(bottom: bottomInset),
      physics: intrinsic
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _AdaptiveSplitSearchResults._wordGridColumns,
        crossAxisSpacing: _AdaptiveSplitSearchResults._wordGridSpacing,
        mainAxisSpacing: _AdaptiveSplitSearchResults._wordGridSpacing,
        mainAxisExtent: _AdaptiveSplitSearchResults._wordGridRowHeight,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return DictionarySearchResultEntrance(
          key: ValueKey('$query-word-grid-$index'),
          index: index + 1,
          child: DictionaryGlassWordSearchResultCard(
            entry: entries[index],
            query: query,
            gridCell: true,
          ),
        );
      },
    );

    final header = DictionarySearchResultEntrance(
      key: ValueKey('header-$query-단어'),
      index: 0,
      child: _SearchResultSectionHeader(
        label: '단어',
        count: count,
        kind: DictionaryItemKind.word,
      ),
    );

    if (intrinsic) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          grid,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: grid),
      ],
    );
  }
}

/// 문장 등 리스트형 검색 결과.
class _SearchResultsSection extends StatelessWidget {
  final String label;
  final String query;
  final int count;
  final Color accent;
  final int itemCount;
  final bool intrinsic;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const _SearchResultsSection({
    required this.label,
    required this.query,
    required this.count,
    required this.accent,
    required this.itemCount,
    required this.itemBuilder,
    this.intrinsic = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = intrinsic ? 4.0 : 4 + FloatingIslandNavBar.scrollBottomPadding(context);

    final listView = ListView.builder(
      shrinkWrap: intrinsic,
      padding: EdgeInsets.only(bottom: bottomInset),
      physics: intrinsic
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return DictionarySearchResultEntrance(
          key: ValueKey('$query-$label-$index'),
          index: index + 1,
          child: itemBuilder(context, index),
        );
      },
    );

    final header = DictionarySearchResultEntrance(
      key: ValueKey('header-$query-$label'),
      index: 0,
      child: _SearchResultSectionHeader(
        label: label,
        count: count,
        kind: DictionaryItemKind.sentence,
      ),
    );

    if (intrinsic) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          listView,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: listView),
      ],
    );
  }
}

class _SearchResultSectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final DictionaryItemKind kind;

  const _SearchResultSectionHeader({
    required this.label,
    required this.count,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final accent = DictionaryItemKindColors.accent(kind);
    final labelColor = DictionaryItemKindColors.label(kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: labelColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: DictionaryItemKindColors.chipBackground(kind),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DictionaryItemKindColors.chipBorder(kind),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSearchPillBar extends ConsumerStatefulWidget {
  final LanguagePalette palette;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool expanded;
  final double compactWidth;
  final double fullWidth;
  final VoidCallback onClear;
  final VoidCallback onExpandTap;

  const _LiveSearchPillBar({
    super.key,
    required this.palette,
    required this.controller,
    required this.focusNode,
    required this.expanded,
    required this.compactWidth,
    required this.fullWidth,
    required this.onClear,
    required this.onExpandTap,
  });

  @override
  ConsumerState<_LiveSearchPillBar> createState() => _LiveSearchPillBarState();
}

class _LiveSearchPillBarState extends ConsumerState<_LiveSearchPillBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final expanded = widget.expanded;
    final searchAccent = widget.palette.searchAccent;
    final searchBorder = widget.palette.searchFieldBorder;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        width: expanded ? widget.fullWidth : widget.compactWidth,
        height: expanded ? 52 : 46,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(expanded ? 22 : 28),
            onTap: expanded ? null : widget.onExpandTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(expanded ? 22 : 28),
                border: Border.all(
                  color: searchBorder,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: expanded ? 22 : 20,
                      color: searchAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        readOnly: !expanded,
                        showCursor: expanded,
                        enableInteractiveSelection: expanded,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                          fontSize: expanded ? 15 : 13.5,
                          fontWeight: FontWeight.w600,
                          color: DashboardPalette.navy.withValues(
                            alpha: expanded ? 1 : 0.72,
                          ),
                        ),
                        cursorColor: searchAccent,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: expanded
                              ? '비상구, 담요, 보조배터리 등 검색...'
                              : '무엇을 찾아볼까요?',
                          hintStyle: TextStyle(
                            fontSize: expanded ? 14 : 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B).withValues(
                              alpha: expanded ? 0.85 : 0.65,
                            ),
                          ),
                        ),
                        onTap: expanded ? null : widget.onExpandTap,
                        onSubmitted: (_) {
                          final q = widget.controller.text.trim();
                          if (q.isNotEmpty) {
                            ref
                                .read(searchProvider.notifier)
                                .submitSearch(q);
                          }
                        },
                      ),
                    ),
                    if (expanded && widget.controller.text.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () {
                          widget.controller.clear();
                          ref.read(searchProvider.notifier).setQuery('');
                          setState(() {});
                        },
                      )
                    else if (expanded)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: widget.onClear,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 하단 즐겨찾기 ─────────────────

class _CompactFavoritesPanel extends StatelessWidget {
  final double inset;
  final LanguagePalette palette;
  final List<DictionaryFavoriteItem> favorites;
  final ValueChanged<DictionaryFavoriteItem> onFavoriteTap;
  final VoidCallback onViewAll;

  const _CompactFavoritesPanel({
    required this.inset,
    required this.palette,
    required this.favorites,
    required this.onFavoriteTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: EdgeInsets.fromLTRB(inset + 14, 12, inset + 14, 12),
        decoration: BoxDecoration(
          color: palette.favoritesSectionBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '⭐ 즐겨찾기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DashboardPalette.navy,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onViewAll,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        '전체보기 ↗',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.searchAccent,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: _CompactFavoritesRow(
                items: favorites,
                palette: palette,
                onTap: onFavoriteTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactFavoritesRow extends StatelessWidget {
  final List<DictionaryFavoriteItem> items;
  final LanguagePalette palette;
  final ValueChanged<DictionaryFavoriteItem> onTap;

  const _CompactFavoritesRow({
    required this.items,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '별표로 저장한 단어·문장이 여기에 표시됩니다',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, i) {
        final item = items[i];
        return _FavoriteChip(
          item: item,
          palette: palette,
          onTap: () => onTap(item),
        );
      },
    );
  }
}

class _FavoriteChip extends StatelessWidget {
  final DictionaryFavoriteItem item;
  final LanguagePalette palette;
  final VoidCallback onTap;

  const _FavoriteChip({
    required this.item,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWord = item is DictionaryFavoriteWordItem;
    final kind =
        isWord ? DictionaryItemKind.word : DictionaryItemKind.sentence;
    final tagLabel = DictionaryItemKindColors.label(kind);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 13, color: Colors.amber.shade600),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: DictionaryItemKindColors.chipBackground(kind),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: DictionaryItemKindColors.chipBorder(kind),
                  ),
                ),
                child: Text(
                  isWord ? '단어' : '문장',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: tagLabel,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  item.chipLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DashboardPalette.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 검색 활성·쿼리 비어 있을 때 — 리퀴드 글래스 검색 기록 패널.
class _DictionarySearchHistoryPanel extends StatelessWidget {
  final LanguagePalette palette;
  final List<String> recentQueries;
  final bool loading;
  final ValueChanged<String> onQueryTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  const _DictionarySearchHistoryPanel({
    required this.palette,
    required this.recentQueries,
    required this.loading,
    required this.onQueryTap,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.glassFill(alpha: 0.74, tint: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.glassBorder(alpha: 0.55),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.07),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 15,
                          color: palette.searchAccent.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '검색 기록',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.15,
                            color: DashboardPalette.navy.withValues(alpha: 0.82),
                          ),
                        ),
                        const Spacer(),
                        if (recentQueries.isNotEmpty)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onClear,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '전체 삭제',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: palette.searchAccent
                                        .withValues(alpha: 0.88),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (loading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.searchAccent.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      )
                    else if (recentQueries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                        child: Text(
                          '최근 검색한 표현이 여기에 표시됩니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: const Color(0xFF64748B).withValues(alpha: 0.9),
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < recentQueries.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _SearchHistoryGlassRow(
                          query: recentQueries[i],
                          palette: palette,
                          onTap: () => onQueryTap(recentQueries[i]),
                          onRemove: () => onRemove(recentQueries[i]),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchHistoryGlassRow extends StatelessWidget {
  final String query;
  final LanguagePalette palette;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SearchHistoryGlassRow({
    required this.query,
    required this.palette,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: palette.searchAccent.withValues(alpha: 0.08),
        highlightColor: palette.searchAccent.withValues(alpha: 0.04),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(11, 9, 4, 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.cardBorder.withValues(alpha: 0.45),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 15,
                color: palette.searchAccent.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: DashboardPalette.navy.withValues(alpha: 0.88),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: DashboardPalette.textMuted.withValues(alpha: 0.55),
                ),
                tooltip: '삭제',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

