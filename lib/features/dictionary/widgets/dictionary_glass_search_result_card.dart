import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dictionary_favorite_providers.dart';
import '../../../app/providers.dart';
import '../../../core/utils/search_highlight.dart';
import '../../../data/models/sentence.dart';
import '../dictionary_item_kind_colors.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../dashboard/dashboard_palette.dart';

/// 문장 검색 결과 — 프리미엄 글래스 사전 리스트 카드.
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              onTap: () => _openLearningMode(context),
              borderRadius: BorderRadius.circular(14),
              splashColor:
                  DictionaryItemKindColors.sentenceAccent.withValues(alpha: 0.06),
              highlightColor:
                  DictionaryItemKindColors.sentenceAccent.withValues(alpha: 0.04),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (categoryLabel.isNotEmpty) ...[
                              _CategoryChip(label: categoryLabel),
                              const SizedBox(height: 8),
                            ],
                            _SentencePreview(
                              sentence: sentence,
                              query: query,
                            ),
                          ],
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
                        onPlayTap: () =>
                            ref.read(audioProvider.notifier).toggle(sentence),
                      ),
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

class _CategoryChip extends StatelessWidget {
  final String label;

  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    const kind = DictionaryItemKind.sentence;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DictionaryItemKindColors.chipBackground(kind),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DictionaryItemKindColors.chipBorder(kind),
          width: 1.0,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: DictionaryItemKindColors.label(kind),
          letterSpacing: -0.1,
          height: 1.1,
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
    const subStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      color: DashboardPalette.textMuted,
      height: 1.3,
    );
    const koreanStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: Color(0xFF94A3B8),
      height: 1.3,
    );

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
            style: subStyle,
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
          decoration: GlassSurfaceStyle.lightGlassButton(radius: size / 2),
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
          decoration: GlassSurfaceStyle.deepDarkGlassButton(radius: radius),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 3,
                left: 8,
                right: 8,
                child: Container(
                  height: 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Icon(
                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 17,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
