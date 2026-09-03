import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dictionary_favorite_providers.dart';
import '../../../app/tts_providers.dart';
import '../../../core/utils/search_highlight.dart';
import '../../../data/models/vocabulary_entry.dart';
import '../dictionary_pronunciation_display.dart';
import '../dictionary_item_kind_colors.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/web_safe_backdrop_blur.dart';
import '../../dashboard/dashboard_palette.dart';

/// 단어 검색 결과 — 그림자 elevation 글래스 카드.
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
    final categoryLabel = entry.category?.trim() ?? '';
    final radius = gridCell ? 10.0 : 12.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: WebSafeBackdropBlur(
        sigmaX: 10,
        sigmaY: 10,
        child: DecoratedBox(
          decoration: DictionaryItemKindColors.elevatedCard(radius: radius),
          child: gridCell
              ? _buildGridCell(
                  context,
                  ref,
                  isSpeaking,
                  isFavorite,
                  categoryLabel,
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
    );
  }

  Widget _buildGridCell(
    BuildContext context,
    WidgetRef ref,
    bool isSpeaking,
    bool isFavorite,
    String categoryLabel,
  ) {
    final pronunciation = DictionaryPronunciationDisplay.wordPronunciation(entry);
    final showsPronunciation =
        DictionaryPronunciationDisplay.showsWordPronunciation(entry);
    final meaning = entry.meaning.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SearchHighlightText(
                  text: entry.term,
                  query: query,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DashboardPalette.navy,
                    height: 1.12,
                  ),
                  highlightColor: SearchHighlightStyle.fill,
                  highlightTextColor: SearchHighlightStyle.text,
                ),
                if (showsPronunciation) ...[
                  const SizedBox(height: 2),
                  SearchHighlightText(
                    text: pronunciation,
                    query: query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: DictionaryPronunciationDisplay.pronunciationColor,
                      height: 1.1,
                    ),
                    highlightColor: SearchHighlightStyle.fill,
                    highlightTextColor: SearchHighlightStyle.text,
                  ),
                ],
                if (meaning.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  SearchHighlightText(
                    text: meaning,
                    query: query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: DashboardPalette.navy.withValues(alpha: 0.55),
                      height: 1.15,
                    ),
                    highlightColor: SearchHighlightStyle.fill,
                    highlightTextColor: SearchHighlightStyle.text,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: DictionarySourceLabel(
                    label: categoryLabel,
                    compact: true,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              _LightGlassIconButton(
                icon: isSpeaking
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
                size: 24,
                iconSize: 13,
                onTap: () => ref.read(ttsSpeakingProvider.notifier).speakWord(
                      word: entry.term,
                      language: entry.language,
                    ),
              ),
              const SizedBox(width: 3),
              _LightGlassIconButton(
                icon: isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                iconColor: isFavorite
                    ? Colors.amber.shade700
                    : GlassSurfaceStyle.iconColor,
                size: 24,
                iconSize: 13,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                if (categoryLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  DictionarySourceLabel(
                    label: categoryLabel,
                    textAlign: TextAlign.left,
                  ),
                ],
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
          decoration: DictionaryItemKindColors.shadowIconButton(
            radius: size / 2,
          ),
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}
