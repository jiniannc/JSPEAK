import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dictionary_favorite_providers.dart';
import '../../../app/dictionary_providers.dart';
import '../../../app/learning_providers.dart';
import '../../../app/providers.dart';
import '../../../app/tts_providers.dart';
import '../../../core/constants/labels.dart';
import '../../../core/theme/language_palette.dart';
import '../../../data/models/sentence.dart';
import '../../../data/models/vocabulary_entry.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../dashboard/dashboard_palette.dart';
import '../../shell/floating_island_nav_bar.dart';
import '../dictionary_item_kind_colors.dart';

enum _BookmarkVaultFilter { all, word, sentence }

/// 사전 즐겨찾기 보관함 — 글로벌 언어 동기화 ModalBottomSheet.
class BookmarkVaultModal extends ConsumerStatefulWidget {
  const BookmarkVaultModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: const BookmarkVaultModal(),
        );
      },
    );
  }

  @override
  ConsumerState<BookmarkVaultModal> createState() => _BookmarkVaultModalState();
}

class _BookmarkVaultModalState extends ConsumerState<BookmarkVaultModal> {
  _BookmarkVaultFilter _filter = _BookmarkVaultFilter.all;

  void _selectLanguage(String language) {
    selectLearningLanguage(ref, language);
  }

  List<DictionaryFavoriteItem> _filtered(List<DictionaryFavoriteItem> items) {
    return switch (_filter) {
      _BookmarkVaultFilter.all => items,
      _BookmarkVaultFilter.word =>
        items.whereType<DictionaryFavoriteWordItem>().toList(),
      _BookmarkVaultFilter.sentence =>
        items.whereType<DictionaryFavoriteSentenceItem>().toList(),
    };
  }

  void _openSentence(Sentence sentence) {
    Navigator.of(context).pop();
    context.push(
      '/scenarios/sentences/play'
      '?lang=${Uri.encodeComponent(sentence.language)}'
      '&category=${Uri.encodeComponent(sentence.category)}',
    );
  }

  void _openWord(VocabularyEntry entry) {
    Navigator.of(context).pop();
    ref.read(dictionarySearchJumpProvider.notifier).apply(entry.term);
    final path = GoRouterState.of(context).uri.path;
    if (path != '/dictionary') {
      context.go('/dictionary');
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(selectedLanguageProvider);
    final palette = LanguagePalette.forLanguage(language);
    final accent = palette.accent;
    final allItems = ref.watch(dictionaryFavoritesAllForLanguageProvider);
    final words = allItems.whereType<DictionaryFavoriteWordItem>().length;
    final sentences = allItems
        .whereType<DictionaryFavoriteSentenceItem>()
        .length;
    final visible = _filtered(allItems);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.82;
    final listBottomPadding = 36 + FloatingIslandNavBar.reservedHeight(context);

    return SizedBox(
      height: sheetHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.0,
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BookmarkVaultStickyHeader(
                    language: language,
                    accent: accent,
                    filter: _filter,
                    totalCount: allItems.length,
                    wordCount: words,
                    sentenceCount: sentences,
                    onLanguageSelected: _selectLanguage,
                    onFilterChanged: (f) => setState(() => _filter = f),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                listBottomPadding,
                              ),
                              child: const _BookmarkVaultEmptyState(),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              14,
                              20,
                              listBottomPadding,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = visible[index];
                              return switch (item) {
                                DictionaryFavoriteWordItem(:final entry) =>
                                  _BookmarkVaultFadeItem(
                                    key: ValueKey(entry.storageFavoriteKey),
                                    onUnfavorite: () => ref
                                        .read(
                                          dictionaryFavoritesProvider.notifier,
                                        )
                                        .toggleWord(entry),
                                    child: _BookmarkWordCard(
                                      entry: entry,
                                      onTap: () => _openWord(entry),
                                    ),
                                  ),
                                DictionaryFavoriteSentenceItem(
                                  :final sentence,
                                ) =>
                                  _BookmarkVaultFadeItem(
                                    key: ValueKey(sentence.storageFavoriteKey),
                                    onUnfavorite: () => ref
                                        .read(
                                          dictionaryFavoritesProvider.notifier,
                                        )
                                        .toggleSentence(sentence),
                                    child: _BookmarkSentenceCard(
                                      sentence: sentence,
                                      onTap: () => _openSentence(sentence),
                                    ),
                                  ),
                              };
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookmarkVaultStickyHeader extends StatelessWidget {
  final String language;
  final Color accent;
  final _BookmarkVaultFilter filter;
  final int totalCount;
  final int wordCount;
  final int sentenceCount;
  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<_BookmarkVaultFilter> onFilterChanged;
  final VoidCallback onClose;

  const _BookmarkVaultStickyHeader({
    required this.language,
    required this.accent,
    required this.filter,
    required this.totalCount,
    required this.wordCount,
    required this.sentenceCount,
    required this.onLanguageSelected,
    required this.onFilterChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DashboardPalette.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const _VaultFavoriteStarIcon(size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        '즐겨찾기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: DashboardPalette.navy,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                _MiniLanguageSwitch(
                  selected: language,
                  accent: accent,
                  onSelected: onLanguageSelected,
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: DashboardPalette.navy.withValues(alpha: 0.55),
                  ),
                  tooltip: '닫기',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _SegmentedFilterBar(
              filter: filter,
              accent: accent,
              totalCount: totalCount,
              wordCount: wordCount,
              sentenceCount: sentenceCount,
              onChanged: onFilterChanged,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _vaultLiquidGlassPill({
  required bool selected,
  required Color accent,
  double radius = 12,
}) {
  return BoxDecoration(
    color: selected
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.62),
          )
        : Colors.white.withValues(alpha: 0.42),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: GlassSurfaceStyle.cleanElevationShadow(blur: selected ? 10 : 6),
  );
}

class _MiniLanguageSwitch extends StatelessWidget {
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  const _MiniLanguageSwitch({
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  static const _codes = {'English': 'EN', 'Japanese': 'JP', 'Chinese': 'CN'};

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final lang in kDictionaryLanguages) ...[
          _LangPill(
            emoji: languageEmoji[lang] ?? '🌐',
            code: _codes[lang] ?? lang.substring(0, 2).toUpperCase(),
            selected: selected == lang,
            accent: accent,
            onTap: () => onSelected(lang),
          ),
          if (lang != kDictionaryLanguages.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _LangPill extends StatelessWidget {
  final String emoji;
  final String code;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _LangPill({
    required this.emoji,
    required this.code,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: _vaultLiquidGlassPill(
            selected: selected,
            accent: accent,
            radius: 10,
          ),
          child: Text(
            '$emoji $code',
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? accent
                  : DashboardPalette.navy.withValues(alpha: 0.55),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedFilterBar extends StatelessWidget {
  final _BookmarkVaultFilter filter;
  final Color accent;
  final int totalCount;
  final int wordCount;
  final int sentenceCount;
  final ValueChanged<_BookmarkVaultFilter> onChanged;

  const _SegmentedFilterBar({
    required this.filter,
    required this.accent,
    required this.totalCount,
    required this.wordCount,
    required this.sentenceCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        boxShadow: GlassSurfaceStyle.cleanElevationShadow(blur: 8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _FilterChip(
              label: '전체 ($totalCount)',
              selected: filter == _BookmarkVaultFilter.all,
              accent: accent,
              onTap: () => onChanged(_BookmarkVaultFilter.all),
            ),
            const SizedBox(width: 4),
            _FilterChip(
              label: '단어 ($wordCount)',
              selected: filter == _BookmarkVaultFilter.word,
              accent: accent,
              onTap: () => onChanged(_BookmarkVaultFilter.word),
            ),
            const SizedBox(width: 4),
            _FilterChip(
              label: '문장 ($sentenceCount)',
              selected: filter == _BookmarkVaultFilter.sentence,
              accent: accent,
              onTap: () => onChanged(_BookmarkVaultFilter.sentence),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: selected
              ? _vaultLiquidGlassPill(selected: true, accent: accent)
              : const BoxDecoration(),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? accent
                  : DashboardPalette.navy.withValues(alpha: 0.62),
              letterSpacing: -0.15,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookmarkVaultEmptyState extends StatelessWidget {
  const _BookmarkVaultEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 36,
              color: DashboardPalette.navy.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              '아직 즐겨찾기한 표현이 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DashboardPalette.navy.withValues(alpha: 0.55),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⭐ 해제 시 페이드아웃 후 Hive에서 제거.
class _BookmarkVaultFadeItem extends StatefulWidget {
  final Widget child;
  final Future<bool> Function() onUnfavorite;

  const _BookmarkVaultFadeItem({
    super.key,
    required this.child,
    required this.onUnfavorite,
  });

  @override
  State<_BookmarkVaultFadeItem> createState() => _BookmarkVaultFadeItemState();
}

class _BookmarkVaultFadeItemState extends State<_BookmarkVaultFadeItem> {
  double _opacity = 1;
  bool _removing = false;

  Future<void> unfavorite() async {
    if (_removing) return;
    _removing = true;
    setState(() => _opacity = 0);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    await widget.onUnfavorite();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: _BookmarkVaultItemScope(
        onUnfavorite: unfavorite,
        child: widget.child,
      ),
    );
  }
}

class _BookmarkVaultItemScope extends InheritedWidget {
  final Future<void> Function() onUnfavorite;

  const _BookmarkVaultItemScope({
    required this.onUnfavorite,
    required super.child,
  });

  static Future<void> Function()? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_BookmarkVaultItemScope>()
        ?.onUnfavorite;
  }

  @override
  bool updateShouldNotify(_BookmarkVaultItemScope oldWidget) =>
      onUnfavorite != oldWidget.onUnfavorite;
}

class _BookmarkWordCard extends ConsumerWidget {
  final VocabularyEntry entry;
  final VoidCallback onTap;

  const _BookmarkWordCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final category = entry.category?.trim() ?? '';

    return _BookmarkGlassShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _TypeTag(label: '단어', kind: DictionaryItemKind.word),
                    if (category.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bookmarkCategoryStyle(DictionaryItemKind.word),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.term,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: DashboardPalette.navy,
                    height: 1.25,
                  ),
                ),
                if (entry.meaning.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.meaning,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: DashboardPalette.navy.withValues(alpha: 0.68),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BookmarkActionRail(
            isFavorite: true,
            isPlaying: isSpeaking,
            hasPlay: true,
            playIcon: isSpeaking
                ? Icons.volume_up_rounded
                : Icons.volume_up_outlined,
            onFavoriteTap: () => _BookmarkVaultItemScope.of(context)?.call(),
            onPlayTap: () => ref
                .read(ttsSpeakingProvider.notifier)
                .speakWord(word: entry.term, language: entry.language),
          ),
        ],
      ),
    );
  }
}

class _BookmarkSentenceCard extends ConsumerWidget {
  final Sentence sentence;
  final VoidCallback onTap;

  const _BookmarkSentenceCard({required this.sentence, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final isPlaying = audioState.playingSentenceId == sentence.id;
    final category = sentence.category.trim();
    final hasAudio = sentence.audioUrl.isNotEmpty;

    return _BookmarkGlassShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _TypeTag(label: '문장', kind: DictionaryItemKind.sentence),
                    if (category.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              _bookmarkCategoryStyle(DictionaryItemKind.sentence),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  sentence.sentence,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DashboardPalette.navy,
                    height: 1.35,
                  ),
                ),
                if (sentence.korean.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sentence.korean,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: DashboardPalette.textMuted.withValues(alpha: 0.9),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BookmarkActionRail(
            isFavorite: true,
            isPlaying: isPlaying,
            hasPlay: hasAudio,
            playIcon: isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            onFavoriteTap: () => _BookmarkVaultItemScope.of(context)?.call(),
            onPlayTap: () => ref.read(audioProvider.notifier).toggle(sentence),
          ),
        ],
      ),
    );
  }
}

class _BookmarkGlassShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BookmarkGlassShell({required this.child, this.onTap});

  static const _cyan = Color(0xFF0EA5E9);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: GlassSurfaceStyle.cardShadow(radius: 14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              splashColor: _cyan.withValues(alpha: 0.06),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  final String label;
  final DictionaryItemKind kind;

  const _TypeTag({required this.label, required this.kind});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: DictionaryItemKindColors.chipBackground(kind),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: DictionaryItemKindColors.chipBorder(kind)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: DictionaryItemKindColors.label(kind),
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

TextStyle _bookmarkCategoryStyle(DictionaryItemKind kind) {
  return TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: DictionaryItemKindColors.categoryText(kind),
  );
}

class _BookmarkActionRail extends StatelessWidget {
  final bool isFavorite;
  final bool isPlaying;
  final bool hasPlay;
  final IconData playIcon;
  final VoidCallback? onFavoriteTap;
  final VoidCallback onPlayTap;

  const _BookmarkActionRail({
    required this.isFavorite,
    required this.isPlaying,
    required this.hasPlay,
    required this.playIcon,
    required this.onFavoriteTap,
    required this.onPlayTap,
  });

  static const _size = 32.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassPressableScale(
          onTap: onFavoriteTap,
          borderRadius: BorderRadius.circular(_size / 2),
          child: SizedBox(
            width: _size,
            height: _size,
            child: DecoratedBox(
              decoration: GlassSurfaceStyle.lightGlassButton(radius: _size / 2),
              child: Center(
                child: _VaultFavoriteStarIcon(
                  size: 17,
                  filled: isFavorite,
                ),
              ),
            ),
          ),
        ),
        if (hasPlay) ...[
          const SizedBox(width: 4),
          GlassPressableScale(
            onTap: onPlayTap,
            borderRadius: BorderRadius.circular(_size / 2),
            child: SizedBox(
              width: _size,
              height: _size,
              child: DecoratedBox(
                decoration: GlassSurfaceStyle.deepDarkGlassButton(
                  radius: _size / 2,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 3,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 0.5,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    Icon(playIcon, size: 17, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 선명한 2D 노란색 — 안쪽이 살짝 오목한 5각 스파클 별.
class _VaultFavoriteStarIcon extends StatelessWidget {
  final double size;
  final bool filled;

  const _VaultFavoriteStarIcon({
    required this.size,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VaultFavoriteStarPainter(filled: filled),
      ),
    );
  }
}

class _VaultFavoriteStarPainter extends CustomPainter {
  final bool filled;

  const _VaultFavoriteStarPainter({required this.filled});

  Path _starPath(Offset center, double outerR, double innerR) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / points) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide * 0.46;
    final innerR = outerR * 0.38;
    final star = _starPath(center, outerR, innerR);

    if (filled) {
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFCA28));
      canvas.drawPath(
        star,
        Paint()
          ..color = const Color(0xFFF9A825)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.055
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(
        Offset(center.dx - outerR * 0.18, center.dy - outerR * 0.22),
        size.shortestSide * 0.055,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      return;
    }

    canvas.drawPath(
      star,
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.065
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VaultFavoriteStarPainter oldDelegate) {
    return oldDelegate.filled != filled;
  }
}
