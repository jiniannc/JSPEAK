import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dictionary_favorite_providers.dart';
import '../../../app/tts_providers.dart';
import '../../../core/utils/search_highlight.dart';
import '../../../data/models/vocabulary_entry.dart';
import '../dictionary_pronunciation_display.dart';
import '../dictionary_item_kind_colors.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../dashboard/dashboard_palette.dart';

/// 단어 검색 결과 — 미니 러기지 택 스타일 글래스 카드.
class DictionaryGlassWordSearchResultCard extends ConsumerWidget {

  final VocabularyEntry entry;
  final String query;
  final bool gridCell;

  const DictionaryGlassWordSearchResultCard({
    super.key,
    required this.entry,
    required this.query,
    this.gridCell = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final favState = ref.watch(dictionaryFavoritesResolvedProvider);
    final isFavorite = favState.contains(entry.storageFavoriteKey);
    final pronunciation = entry.pronunciation?.trim() ?? '';
    final showPronunciation =
        DictionaryPronunciationDisplay.showsWordPronunciation(entry);
    final categoryLabel = entry.category?.trim() ?? '';
    final radius = gridCell ? 10.0 : 12.0;

    return Container(
      margin: EdgeInsets.only(bottom: gridCell ? 0 : 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: GlassSurfaceStyle.cardShadow(radius: radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.0,
              ),
            ),
            child: gridCell
                ? _buildGridCell(
                    context,
                    ref,
                    isSpeaking,
                    isFavorite,
                    categoryLabel,
                    showPronunciation: showPronunciation,
                    pronunciation: pronunciation,
                  )
                : _buildListCell(
                    context,
                    ref,
                    isSpeaking,
                    isFavorite,
                    pronunciation,
                    categoryLabel: categoryLabel,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridCell(
    BuildContext context,
    WidgetRef ref,
    bool isSpeaking,
    bool isFavorite,
    String categoryLabel, {
    required bool showPronunciation,
    required String pronunciation,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (categoryLabel.isNotEmpty) ...[
            _MiniTypeTag(
              label: categoryLabel,
              compact: true,
            ),
            const SizedBox(height: 5),
          ],
          SearchHighlightText(
            text: entry.term,
            query: query,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: DashboardPalette.navy,
              height: 1.15,
            ),
            highlightColor: SearchHighlightStyle.fill,
            highlightTextColor: SearchHighlightStyle.text,
          ),
          if (showPronunciation) ...[
            const SizedBox(height: 2),
            Text(
              pronunciation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: DashboardPalette.textMuted.withValues(alpha: 0.9),
                height: 1.15,
              ),
            ),
          ],
          const SizedBox(height: 3),
          Expanded(
            child: SearchHighlightText(
              text: entry.meaning,
              query: query,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: DashboardPalette.navy.withValues(alpha: 0.68),
                height: 1.2,
              ),
              highlightColor: SearchHighlightStyle.fill,
              highlightTextColor: SearchHighlightStyle.text,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _LightGlassIconButton(
                icon: isSpeaking
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
                size: 26,
                iconSize: 14,
                onTap: () => ref.read(ttsSpeakingProvider.notifier).speakWord(
                      word: entry.term,
                      language: entry.language,
                    ),
              ),
              const SizedBox(width: 4),
              _LightGlassIconButton(
                icon: isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                iconColor: isFavorite
                    ? Colors.amber.shade700
                    : GlassSurfaceStyle.iconColor,
                size: 26,
                iconSize: 14,
                onTap: () async {
                  final added = await ref
                      .read(dictionaryFavoritesProvider.notifier)
                      .toggleWord(entry);
                  if (context.mounted) {
                    showDictionaryFavoriteSnackBar(context, added: added);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListCell(
    BuildContext context,
    WidgetRef ref,
    bool isSpeaking,
    bool isFavorite,
    String pronunciation, {
    required String categoryLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (categoryLabel.isNotEmpty) ...[
                  _MiniTypeTag(label: categoryLabel),
                  const SizedBox(height: 6),
                ],
                SearchHighlightText(
                  text: entry.term,
                  query: query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: DashboardPalette.navy,
                    height: 1.2,
                  ),
                  highlightColor: SearchHighlightStyle.fill,
                  highlightTextColor: SearchHighlightStyle.text,
                ),
                if (pronunciation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    pronunciation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          DictionaryPronunciationDisplay.isCjkLanguage(
                            entry.language,
                          )
                          ? FontStyle.normal
                          : FontStyle.italic,
                      color: DashboardPalette.textMuted.withValues(alpha: 0.9),
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                SearchHighlightText(
                  text: entry.meaning,
                  query: query,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: DashboardPalette.navy.withValues(alpha: 0.72),
                    height: 1.25,
                  ),
                  highlightColor: SearchHighlightStyle.fill,
                  highlightTextColor: SearchHighlightStyle.text,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LightGlassIconButton(
                icon: isSpeaking
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
                onTap: () => ref.read(ttsSpeakingProvider.notifier).speakWord(
                      word: entry.term,
                      language: entry.language,
                    ),
              ),
              const SizedBox(height: 4),
              _LightGlassIconButton(
                icon: isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                iconColor: isFavorite
                    ? Colors.amber.shade700
                    : GlassSurfaceStyle.iconColor,
                onTap: () async {
                  final added = await ref
                      .read(dictionaryFavoritesProvider.notifier)
                      .toggleWord(entry);
                  if (context.mounted) {
                    showDictionaryFavoriteSnackBar(context, added: added);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTypeTag extends StatelessWidget {
  final String label;
  final bool compact;

  const _MiniTypeTag({
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const kind = DictionaryItemKind.word;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: DictionaryItemKindColors.chipBackground(kind),
        borderRadius: BorderRadius.circular(compact ? 5 : 8),
        border: Border.all(
          color: DictionaryItemKindColors.chipBorder(kind),
          width: 1.0,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 8.5 : 9.5,
          fontWeight: FontWeight.w800,
          color: DictionaryItemKindColors.label(kind),
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _LightGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const _LightGlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = 30,
    this.iconSize = 16,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? GlassSurfaceStyle.iconColor;

    return GlassPressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: GlassSurfaceStyle.lightGlassButton(radius: size / 2),
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}
