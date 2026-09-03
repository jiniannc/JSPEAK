import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dictionary_favorite_providers.dart';
import '../../../app/providers.dart';
import '../../../core/utils/search_highlight.dart';
import '../../../data/models/sentence.dart';
import '../dictionary_pronunciation_display.dart';
import '../dictionary_item_kind_colors.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/web_safe_backdrop_blur.dart';
import '../../dashboard/dashboard_palette.dart';

/// 문장 검색 결과 — 그림자 elevation 글래스 리스트 카드.
class DictionaryGlassSearchResultCard extends ConsumerWidget {
  static const _actionSize = 32.0;

  final Sentence sentence;
  final String query;
  final Color accent;

  const DictionaryGlassSearchResultCard({
    super.key,
    required this.sentence,
    required this.query,
    required this.accent,
  });

  void _openLearningMode(BuildContext context) {
    context.push(
      '/scenarios/sentences/play'
      '?lang=${Uri.encodeComponent(sentence.language)}'
      '&category=${Uri.encodeComponent(sentence.category)}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final isPlaying = audioState.playingSentenceId == sentence.id;
    final favState = ref.watch(dictionaryFavoritesResolvedProvider);
    final isFavorite = favState.contains(sentence.storageFavoriteKey);
    final categoryLabel = sentence.category.trim();
    final hasAudio = sentence.audioUrl.isNotEmpty;
    if (hasAudio) {
      ref.read(audioProvider.notifier).prefetch(sentence);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: WebSafeBackdropBlur(
          sigmaX: 10,
          sigmaY: 10,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openLearningMode(context),
              splashColor: DictionaryItemKindColors.rippleColor(
                DictionaryItemKind.sentence,
              ),
              highlightColor: DictionaryItemKindColors.rippleColor(
                DictionaryItemKind.sentence,
              ).withValues(alpha: 0.75),
              child: Ink(
                decoration: DictionaryItemKindColors.elevatedCard(radius: 14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SentencePreview(
                              sentence: sentence,
                              query: query,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SentenceActionRail(
                            isFavorite: isFavorite,
                            isPlaying: isPlaying,
                            hasAudio: hasAudio,
                            onFavoriteTap: () async {
                              final added = await ref
                                  .read(dictionaryFavoritesProvider.notifier)
                                  .toggleSentence(sentence);
                              if (context.mounted) {
                                showDictionaryFavoriteSnackBar(
                                  context,
                                  added: added,
                                );
                              }
                            },
                            onPlayTap: () => ref
                                .read(audioProvider.notifier)
                                .toggle(sentence),
                          ),
                        ],
                      ),
                      if (categoryLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: DictionarySourceLabel(
                            label: categoryLabel,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ],
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

class _SentencePreview extends StatelessWidget {
  final Sentence sentence;
  final String query;

  const _SentencePreview({
    required this.sentence,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    const sentenceStyle = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      color: DashboardPalette.navy,
      height: 1.35,
    );
    const koreanStyle = DictionaryPronunciationDisplay.sentenceKoreanStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchHighlightText(
          text: sentence.sentence,
          query: query,
          style: sentenceStyle,
          highlightColor: SearchHighlightStyle.fill,
          highlightTextColor: SearchHighlightStyle.text,
        ),
        if (sentence.pronunciation.isNotEmpty) ...[
          const SizedBox(height: 4),
          SearchHighlightText(
            text: sentence.pronunciation,
            query: query,
            style: DictionaryPronunciationDisplay.sentencePronunciationStyle(
              sentence.language,
            ),
            highlightColor: SearchHighlightStyle.fill,
            highlightTextColor: SearchHighlightStyle.text,
          ),
        ],
        if (sentence.korean.isNotEmpty) ...[
          const SizedBox(height: 3),
          SearchHighlightText(
            text: sentence.korean,
            query: query,
            style: koreanStyle,
            highlightColor: SearchHighlightStyle.fill,
            highlightTextColor: SearchHighlightStyle.text,
          ),
        ],
      ],
    );
  }
}

class _SentenceActionRail extends StatelessWidget {
  final bool isFavorite;
  final bool isPlaying;
  final bool hasAudio;
  final VoidCallback onFavoriteTap;
  final VoidCallback onPlayTap;

  const _SentenceActionRail({
    required this.isFavorite,
    required this.isPlaying,
    required this.hasAudio,
    required this.onFavoriteTap,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LightGlassActionButton(
          icon: isFavorite
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          iconColor: isFavorite
              ? Colors.amber.shade700
              : GlassSurfaceStyle.iconColor,
          onTap: onFavoriteTap,
        ),
        if (hasAudio) ...[
          const SizedBox(width: 4),
          _DeepGlassPlayButton(
            isPlaying: isPlaying,
            onTap: onPlayTap,
          ),
        ],
      ],
    );
  }
}

class _LightGlassActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _LightGlassActionButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = DictionaryGlassSearchResultCard._actionSize;

    return GlassPressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: DictionaryItemKindColors.shadowIconButton(radius: size / 2),
          child: Icon(icon, size: 17, color: iconColor),
        ),
      ),
    );
  }
}

class _DeepGlassPlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _DeepGlassPlayButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = DictionaryGlassSearchResultCard._actionSize;
    const radius = size / 2;

    return GlassPressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: DictionaryItemKindColors.shadowPlayButton(radius: radius),
          child: Icon(
            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 17,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
