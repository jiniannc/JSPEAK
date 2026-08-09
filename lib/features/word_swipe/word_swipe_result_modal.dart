import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/crew_check_in_provider.dart';
import '../../app/dictionary_favorite_providers.dart';
import '../../app/tts_providers.dart';
import '../../core/constants/labels.dart';
import '../../data/models/word_model.dart';
import '../../shared/widgets/score_celebration_overlay.dart';
import '../dashboard/dashboard_palette.dart';

enum _WordSwipeResultFilter { known, needReview }

/// 정답률(0~100) 기반 6단계 성과 티어.
class _WordSwipeScoreTier {
  final String title;
  final String medal;
  final String message;
  final Color badgeColor;

  const _WordSwipeScoreTier({
    required this.title,
    required this.medal,
    required this.message,
    required this.badgeColor,
  });

  static _WordSwipeScoreTier fromAccuracy(int accuracyPercentage) {
    if (accuracyPercentage == 0) {
      return const _WordSwipeScoreTier(
        title: 'CHECK-IN NEEDED',
        medal: '🎫',
        message: '아직 출발 전이에요! 가벼운 마음으로 하나씩 알아가볼까요? 🌱',
        badgeColor: Color(0xFF64748B),
      );
    }
    if (accuracyPercentage == 100) {
      return const _WordSwipeScoreTier(
        title: 'FIRST CLASS MASTER',
        medal: '👑',
        message: '완벽 그 자체! 오늘 단어는 현지인 레벨 달성입니다! 🎉',
        badgeColor: Color(0xFF9333EA),
      );
    }
    if (accuracyPercentage >= 91) {
      return const _WordSwipeScoreTier(
        title: "CAPTAIN'S CHOICE",
        medal: '💎',
        message: '아까운 한 끝 차이! 완벽까지 딱 한 걸음 남았습니다 ⭐',
        badgeColor: Color(0xFF0D9488),
      );
    }
    if (accuracyPercentage >= 71) {
      return const _WordSwipeScoreTier(
        title: 'BUSINESS CLASS',
        medal: '🥇',
        message: '훌륭한 회화 실력! 마스터까지 얼마 안 남았어요 👏',
        badgeColor: Color(0xFFCA8A04),
      );
    }
    if (accuracyPercentage >= 51) {
      return const _WordSwipeScoreTier(
        title: 'READY FOR TAKE-OFF',
        medal: '🥈',
        message: '안정적으로 순항 중! 조금만 더 연습하면 이륙 준비 완료 ✈️',
        badgeColor: Color(0xFF0284C7),
      );
    }
    return const _WordSwipeScoreTier(
      title: 'FLIGHT CHALLENGER',
      medal: '🥉',
      message: '시작이 반이에요! 모르는 단어만 쏙쏙 다시 시도해볼까요? 🔥',
      badgeColor: Color(0xFFD97706),
    );
  }
}

/// 단어 스와이프 챕터 완료 — 게이밍 스타일 비행 학습 리포트 바텀시트.
class WordSwipeResultModal extends ConsumerStatefulWidget {
  final List<WordModel> allWords;
  final List<WordModel> unknownWords;
  final String category;
  final String language;
  final String? nextCategory;
  final VoidCallback onRetryLimited;
  final VoidCallback onRetryFull;
  final VoidCallback? onNextChapter;
  final VoidCallback onExit;

  const WordSwipeResultModal({
    super.key,
    required this.allWords,
    required this.unknownWords,
    required this.category,
    required this.language,
    this.nextCategory,
    required this.onRetryLimited,
    required this.onRetryFull,
    this.onNextChapter,
    required this.onExit,
  });

  static Future<void> show({
    required BuildContext context,
    required List<WordModel> allWords,
    required List<WordModel> unknownWords,
    required String category,
    required String language,
    String? nextCategory,
    required VoidCallback onRetryLimited,
    required VoidCallback onRetryFull,
    VoidCallback? onNextChapter,
    required VoidCallback onExit,
  }) {
    final knownCount = allWords.length - unknownWords.length;
    final successPercent = allWords.isEmpty
        ? 0
        : ((knownCount / allWords.length) * 100).round();
    final celebrationTier = ScoreCelebrationTier.fromPercent(successPercent);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        final screenSize = MediaQuery.sizeOf(sheetContext);
        final sheetHeight = screenSize.height * 0.90;
        return SizedBox(
          height: screenSize.height,
          width: screenSize.width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: sheetHeight,
                  child: WordSwipeResultModal(
                    allWords: allWords,
                    unknownWords: unknownWords,
                    category: category,
                    language: language,
                    nextCategory: nextCategory,
                    onRetryLimited: () {
                      Navigator.of(sheetContext).pop();
                      onRetryLimited();
                    },
                    onRetryFull: () {
                      Navigator.of(sheetContext).pop();
                      onRetryFull();
                    },
                    onNextChapter: onNextChapter == null
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            onNextChapter();
                          },
                    onExit: () {
                      Navigator.of(sheetContext).pop();
                      onExit();
                    },
                  ),
                ),
              ),
              if (celebrationTier != ScoreCelebrationTier.none)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ScoreCelebrationOverlay(tier: celebrationTier),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  ConsumerState<WordSwipeResultModal> createState() =>
      _WordSwipeResultModalState();
}

class _WordSwipeResultModalState extends ConsumerState<WordSwipeResultModal>
    with SingleTickerProviderStateMixin {
  static const _emerald = Color(0xFF10B981);
  static const _cyan = Color(0xFF06B6D4);
  static const _coral = Color(0xFFF43F5E);
  static const _slate = Color(0xFF0F172A);
  static const _subMuted = Color(0xFF64748B);

  late final AnimationController _chartController;
  _WordSwipeResultFilter _filter = _WordSwipeResultFilter.needReview;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
    if (_successPercent >= 100) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.heavyImpact();
      });
    } else if (_successPercent >= 90) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.mediumImpact();
      });
    }
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  List<WordModel> get _knownWords {
    final unknownIds = widget.unknownWords.map((w) => w.id).toSet();
    return [
      for (final w in widget.allWords)
        if (!unknownIds.contains(w.id)) w,
    ];
  }

  int get _total => widget.allWords.length;

  int get _knownCount => _knownWords.length;

  int get _unknownCount => widget.unknownWords.length;

  double get _successRatio => _total == 0 ? 0 : _knownCount / _total;

  int get _successPercent => (_successRatio * 100).round();

  _WordSwipeScoreTier get _scoreTier =>
      _WordSwipeScoreTier.fromAccuracy(_successPercent);

  bool get _allMastered => _unknownCount == 0;

  int get _xpGained => _knownCount * 10;

  List<WordModel> get _visibleWords => switch (_filter) {
        _WordSwipeResultFilter.known => _knownWords,
        _WordSwipeResultFilter.needReview => widget.unknownWords,
      };

  @override
  Widget build(BuildContext context) {
    final retryCount = math.min(5, _unknownCount);
    final checkIn = ref.watch(crewCheckInProvider);
    final streak = math.max(
      1,
      checkIn.asData?.value.consecutiveStreak ?? 1,
    );
    final scoreTier = _scoreTier;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModalHeader(onClose: widget.onExit),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  '${languageLabel(widget.language)} · ${widget.category}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _slate.withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _RankBadge(tier: scoreTier),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 115,
                  height: 115,
                  child: AnimatedBuilder(
                  animation: _chartController,
                  builder: (context, _) {
                    final animatedValue =
                        Curves.easeOutCubic.transform(_chartController.value);
                    final displayPercent =
                        (_successPercent * animatedValue).round();
                    final displayKnown =
                        (_knownCount * animatedValue).round();
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DonutProgressPainter(
                              knownRatio: _successRatio,
                              animationValue: animatedValue,
                              knownGradientColors: const [_emerald, _cyan],
                              unknownColor: _coral,
                              trackColor: _slate.withValues(alpha: 0.06),
                              strokeWidth: 11,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$displayPercent%',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: _slate,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$displayKnown/$_total개',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _slate.withValues(alpha: 0.45),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  scoreTier.message,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _subMuted,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RewardChip(
                    label: '⚡ +$_xpGained XP',
                    background: const Color(0xFFFEF3C7),
                    foreground: const Color(0xFF92700F),
                  ),
                  const SizedBox(width: 8),
                  _RewardChip(
                    label: '🔥 연속 $streak일 학습',
                    background: const Color(0xFFFFEDD5),
                    foreground: const Color(0xFF9A3412),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _SegmentFilter(
                  knownCount: _knownCount,
                  unknownCount: _unknownCount,
                  selected: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ),
              Expanded(
                child: _visibleWords.isEmpty
                    ? Center(
                        child: Text(
                          _filter == _WordSwipeResultFilter.known
                              ? '아직 확실히 아는 단어가 없어요'
                              : '복습할 단어가 없어요 🎉',
                          style: TextStyle(
                            fontSize: 13,
                            color: _slate.withValues(alpha: 0.45),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        itemCount: _visibleWords.length,
                        separatorBuilder: (context, _) => Divider(
                          height: 1,
                          color: _slate.withValues(alpha: 0.06),
                        ),
                        itemBuilder: (context, index) {
                          final word = _visibleWords[index];
                          return _ResultWordRow(
                            word: word,
                            category: widget.category,
                          );
                        },
                      ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  border: Border(
                    top: BorderSide(color: _slate.withValues(alpha: 0.06)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_allMastered) ...[
                          _LiquidGlassActionButton(
                            onPressed: widget.onRetryLimited,
                            label: '모르는 단어 $retryCount개만 재도전',
                          ),
                          if (widget.onNextChapter != null) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: widget.onNextChapter,
                              style: TextButton.styleFrom(
                                foregroundColor: _subMuted,
                                minimumSize: const Size.fromHeight(40),
                              ),
                              child: Text(
                                '다음 챕터 진행 · ${widget.nextCategory}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          _LiquidGlassActionButton(
                            onPressed: widget.onRetryFull,
                            label: '다시 복습하기',
                          ),
                          if (widget.onNextChapter != null) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: widget.onNextChapter,
                              style: TextButton.styleFrom(
                                foregroundColor: _subMuted,
                                minimumSize: const Size.fromHeight(40),
                              ),
                              child: Text(
                                '다음 챕터 진행 · ${widget.nextCategory}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: widget.onExit,
                              style: TextButton.styleFrom(
                                foregroundColor: _subMuted,
                                minimumSize: const Size.fromHeight(40),
                              ),
                              child: const Text(
                                '🎉 학습 완료 · 나가기',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
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

class _ModalHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _ModalHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
      child: Row(
        children: [
          const Text(
            '✈ CHAPTER COMPLETE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Text(
              '✕',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A).withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 정답률 기반 6단계 기내 랭크 뱃지.
class _RankBadge extends StatelessWidget {
  final _WordSwipeScoreTier tier;

  const _RankBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tier.badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tier.medal, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                tier.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: tier.badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _RewardChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _SegmentFilter extends StatelessWidget {
  final int knownCount;
  final int unknownCount;
  final _WordSwipeResultFilter selected;
  final ValueChanged<_WordSwipeResultFilter> onChanged;

  const _SegmentFilter({
    required this.knownCount,
    required this.unknownCount,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: _SegmentChip(
                label: '🟢 학습 완료 ($knownCount)',
                selected: selected == _WordSwipeResultFilter.known,
                onTap: () => onChanged(_WordSwipeResultFilter.known),
              ),
            ),
            Expanded(
              child: _SegmentChip(
                label: '🔴 복습 필요 ($unknownCount)',
                selected: selected == _WordSwipeResultFilter.needReview,
                onTap: () => onChanged(_WordSwipeResultFilter.needReview),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.95)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF0F172A).withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultWordRow extends ConsumerWidget {
  final WordModel word;
  final String category;

  const _ResultWordRow({
    required this.word,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = word.toVocabularyEntry(category: category);
    final isBookmarked = ref
        .watch(dictionaryFavoritesResolvedProvider)
        .contains(entry.storageFavoriteKey);
    final isSpeaking = ref.watch(ttsSpeakingProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  word.meaning,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DashboardPalette.tealDeep,
                  ),
                ),
              ],
            ),
          ),
          _ResultIconTap(
            onTap: isSpeaking
                ? null
                : () {
                    ref.read(ttsSpeakingProvider.notifier).speakWord(
                          word: word.word,
                          language: WordModel.sheetLanguage(word.language),
                        );
                  },
            child: Icon(
              Icons.volume_up_rounded,
              size: 20,
              color: isSpeaking
                  ? DashboardPalette.teal.withValues(alpha: 0.35)
                  : DashboardPalette.tealDeep,
            ),
          ),
          _ResultIconTap(
            onTap: () async {
              HapticFeedback.selectionClick();
              final added = await ref
                  .read(dictionaryFavoritesProvider.notifier)
                  .toggleWord(entry);
              if (context.mounted) {
                showDictionaryFavoriteSnackBar(context, added: added);
              }
            },
            child: Icon(
              isBookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color: isBookmarked
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF94A3B8).withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultIconTap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ResultIconTap({
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _LiquidGlassActionButton({
    required this.onPressed,
    required this.label,
  });

  static const _textShadows = [
    Shadow(
      color: Color(0x40000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    Shadow(
      color: Color(0x26000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x550D9488),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Ink(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xF10D9488), Color(0xF10891B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: _textShadows,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 네온 에메랄드-시안 그래디언트 + 글로우가 적용된 도넛 진행 차트.
class _DonutProgressPainter extends CustomPainter {
  final double knownRatio;
  final double animationValue;
  final List<Color> knownGradientColors;
  final Color unknownColor;
  final Color trackColor;
  final double strokeWidth;

  const _DonutProgressPainter({
    required this.knownRatio,
    required this.animationValue,
    required this.knownGradientColors,
    required this.unknownColor,
    required this.trackColor,
    this.strokeWidth = 11,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = strokeWidth;
    final radius = math.min(size.width, size.height) / 2 - stroke - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final knownSweep = 2 * math.pi * knownRatio * animationValue;
    final unknownRatio = (1 - knownRatio).clamp(0.0, 1.0);
    final unknownSweep = 2 * math.pi * unknownRatio * animationValue;

    // 글로우 레이어 — 얇은 링 바로 뒤에 은은하게 번지는 빛.
    if (knownSweep > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 8
        ..strokeCap = StrokeCap.round
        ..color = knownGradientColors.last.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(rect, startAngle, knownSweep, false, glowPaint);
    }
    if (unknownSweep > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 8
        ..strokeCap = StrokeCap.round
        ..color = unknownColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(
        rect,
        startAngle + knownSweep,
        unknownSweep,
        false,
        glowPaint,
      );
    }

    if (knownSweep > 0) {
      final gradient = SweepGradient(
        colors: knownGradientColors,
        startAngle: startAngle,
        endAngle: startAngle + math.max(knownSweep, 0.001),
      );
      canvas.drawArc(
        rect,
        startAngle,
        knownSweep,
        false,
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    if (unknownSweep > 0) {
      canvas.drawArc(
        rect,
        startAngle + knownSweep,
        unknownSweep,
        false,
        Paint()
          ..color = unknownColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutProgressPainter oldDelegate) {
    return oldDelegate.knownRatio != knownRatio ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
