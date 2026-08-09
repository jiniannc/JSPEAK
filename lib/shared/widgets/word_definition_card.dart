import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tts_providers.dart';
import '../../data/models/vocabulary_entry.dart';
import 'glass_surface.dart';
import 'ipa_stress_text.dart';

/// Popular(1~3) 중요도 뱃지.
class PopularBadge extends StatelessWidget {
  final int popular;
  final bool important;

  const PopularBadge({
    super.key,
    required this.popular,
    this.important = false,
  });

  @override
  Widget build(BuildContext context) {
    final level = popular.clamp(0, 3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (important)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: GlassSurfaceStyle.badgeBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: GlassSurfaceStyle.dividerColor.withValues(alpha: 0.6),
              ),
            ),
            child: const Text(
              '필수',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: GlassSurfaceStyle.iconColor,
              ),
            ),
          ),
        ...List.generate(3, (i) {
          final filled = i < level;
          return Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Icon(
              filled ? Icons.circle : Icons.circle_outlined,
              size: 10,
              color: filled
                  ? GlassSurfaceStyle.iconColor
                  : GlassSurfaceStyle.dividerColor,
            ),
          );
        }),
      ],
    );
  }
}

/// 단어 상세 미니 카드 (오버레이 팝업 본문).
class WordDefinitionCard extends ConsumerWidget {
  final VocabularyEntry entry;
  final VoidCallback onClose;

  const WordDefinitionCard({
    super.key,
    required this.entry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final showIpa = entry.language == 'English' &&
        entry.pronunciation != null &&
        entry.pronunciation!.isNotEmpty;

    return GlassSurface(
      radius: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              border: Border(
                bottom: BorderSide(
                  color: GlassSurfaceStyle.dividerColor.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Row(
              children: [
                PopularBadge(
                  popular: entry.popular,
                  important: entry.important,
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: GlassSurfaceStyle.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.term,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: GlassSurfaceStyle.titleColor,
                    letterSpacing: -0.3,
                  ),
                ),
                if (showIpa) ...[
                  const SizedBox(height: 6),
                  IpaStressText(
                    ipa: entry.pronunciation!,
                    baseStyle: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: GlassSurfaceStyle.subtitleColor,
                    ),
                  ),
                ] else if (entry.pronunciation != null &&
                    entry.pronunciation!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.pronunciation!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: GlassSurfaceStyle.subtitleColor,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  entry.meaning,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GlassSurfaceStyle.titleColor,
                    height: 1.4,
                  ),
                ),
                if (entry.description != null &&
                    entry.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: GlassSurfaceStyle.subtitleColor,
                      height: 1.45,
                    ),
                  ),
                ],
                if (entry.category != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: GlassSurfaceStyle.badgeBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.category!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: GlassSurfaceStyle.iconColor,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: DecoratedBox(
                    decoration: GlassSurfaceStyle.deepDarkGlassButton(
                      radius: 18,
                      opacity: 0.9,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: isSpeaking
                            ? null
                            : () => ref
                                .read(ttsSpeakingProvider.notifier)
                                .speakWord(
                                  word: entry.term,
                                  language: entry.language,
                                ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSpeaking)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Text(
                                '듣기 ▶',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            if (isSpeaking) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '재생 중…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
