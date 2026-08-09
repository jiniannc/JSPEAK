import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/dictionary_favorite_providers.dart';
import '../../app/speech_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/language_palette.dart';
import '../../data/models/sentence.dart';
import '../../features/dashboard/dashboard_palette.dart';
import 'spoken_sentence_rich_text.dart';
import 'tappable_sentence_rich_text.dart';

/// 문장 카드 표시 모드.
enum SentenceCardMode {
  /// 기내 사전 리스트 — 듣기만, 컴팩트.
  list,

  /// 일반 — 재생 + 발음 연습.
  standard,
}

/// 문장 하나를 표시하는 글래스모피즘 카드.
class SentenceCard extends ConsumerWidget {
  final Sentence sentence;
  final bool showOrigin;
  final SentenceCardMode mode;
  final bool showFavoriteToggle;

  const SentenceCard({
    super.key,
    required this.sentence,
    this.showOrigin = false,
    this.mode = SentenceCardMode.standard,
    this.showFavoriteToggle = false,
  });

  bool get _isList => mode == SentenceCardMode.list;
  double get _borderRadius => _isList ? 16.0 : 24.0;
  double get _contentPadding => _isList ? 12.0 : 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final speechState = ref.watch(speechPracticeProvider);
    final isPlaying = audioState.playingSentenceId == sentence.id;
    final isLoading = isPlaying && audioState.loading;
    final isActiveSentence = speechState.activeSentenceId == sentence.id;
    final isListening = isActiveSentence && speechState.isListening;
    final isSpeechInitializing =
        isActiveSentence && speechState.isInitializing;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.languagePalette;
    final accent = palette?.accent ?? scheme.primary;
    final metrics = Active5Layout.of(context);
    final hasAudio = sentence.audioUrl.isNotEmpty;
    final favState = ref.watch(dictionaryFavoritesResolvedProvider);
    final isFavorite = favState.contains(sentence.storageFavoriteKey);

    return Padding(
      padding: EdgeInsets.only(bottom: _isList ? 6 : 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _isList ? 8 : 10,
            sigmaY: _isList ? 8 : 10,
          ),
          child: DecoratedBox(
            decoration: (palette ?? LanguagePalette.english).glassCardDecoration(
              radius: _borderRadius,
              fillAlpha: _isList ? 0.5 : 0.55,
              borderAlpha: 0.42,
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: _isList ? 12 : 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(_contentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            TappableSentenceRichText(
                              sentence: sentence.sentence,
                              style: TextStyle(
                                fontSize: _isList
                                    ? metrics.sentenceFontSize - 1
                                    : metrics.sentenceFontSize,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                color: DashboardPalette.navy,
                              ),
                            ),
                            if (_isList && hasAudio)
                              _InlineGlassAudioButton(
                                accent: accent,
                                isPlaying: isPlaying,
                                isLoading: isLoading,
                                onTap: () => ref
                                    .read(audioProvider.notifier)
                                    .toggle(sentence),
                              ),
                            if (sentence.stars > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < sentence.stars; i++)
                                    Icon(
                                      Icons.star_rounded,
                                      size: _isList ? 14 : 20,
                                      color: Colors.amber.shade600,
                                    ),
                                ],
                              ),
                            if (sentence.important)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '필수',
                                  style: TextStyle(
                                    fontSize: _isList ? 10 : 13,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (showFavoriteToggle || _isList) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: isFavorite ? '즐겨찾기 해제' : '즐겨찾기 저장',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: () async {
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
                          icon: Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 22,
                            color: isFavorite
                                ? Colors.amber.shade700
                                : DashboardPalette.textMuted
                                    .withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                      if (!_isList) ...[
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _GlassControlButton(
                              accent: accent,
                              size: 48,
                              tooltip: isListening ? '녹음 중지' : '발음 연습',
                              onPressed: () => ref
                                  .read(speechPracticeProvider.notifier)
                                  .toggle(sentence),
                              icon: isSpeechInitializing
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accent,
                                      ),
                                    )
                                  : Icon(
                                      isListening
                                          ? Icons.mic_rounded
                                          : Icons.mic_none_rounded,
                                      size: 24,
                                      color: isListening
                                          ? scheme.error
                                          : accent,
                                    ),
                            ),
                            if (hasAudio) ...[
                              const SizedBox(width: 8),
                              _GlassControlButton(
                                accent: accent,
                                size: 48,
                                tooltip: isPlaying ? '정지' : '재생',
                                onPressed: () => ref
                                    .read(audioProvider.notifier)
                                    .toggle(sentence),
                                icon: isLoading
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: accent,
                                        ),
                                      )
                                    : Icon(
                                        isPlaying
                                            ? Icons.stop_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 24,
                                        color: accent,
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (sentence.pronunciation.isNotEmpty) ...[
                    SizedBox(height: _isList ? 4 : 10),
                    Text(
                      sentence.pronunciation,
                      style: TextStyle(
                        fontSize: _isList
                            ? metrics.pronunciationFontSize - 2
                            : metrics.pronunciationFontSize,
                        fontStyle: FontStyle.italic,
                        color: DashboardPalette.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (sentence.korean.isNotEmpty) ...[
                    SizedBox(height: _isList ? 2 : 8),
                    Text(
                      sentence.korean,
                      style: TextStyle(
                        fontSize: _isList
                            ? metrics.koreanFontSize - 1
                            : metrics.koreanFontSize,
                        fontWeight: FontWeight.w500,
                        color: DashboardPalette.navy.withValues(alpha: 0.62),
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (!_isList &&
                      isActiveSentence &&
                      (speechState.spokenText.isNotEmpty ||
                          speechState.isListening)) ...[
                    const SizedBox(height: 14),
                    Text(
                      isListening ? '인식 중…' : '내 발음',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (speechState.spokenText.isEmpty)
                      Text(
                        '말씀해 주세요',
                        style: TextStyle(
                          fontSize: metrics.sentenceFontSize - 2,
                          color: DashboardPalette.textMuted,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      )
                    else
                      SpokenSentenceRichText(
                        correctSentence: sentence.sentence,
                        spokenText: speechState.spokenText,
                        language: sentence.language,
                        correctPronunciation: sentence.pronunciation,
                        enableTapToHear:
                            sentence.language == 'Japanese' ||
                            sentence.language == 'Chinese',
                        style: TextStyle(
                          fontSize: metrics.sentenceFontSize - 2,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                        correctColor: DashboardPalette.navy,
                      ),
                  ],
                  if (!_isList &&
                      isActiveSentence &&
                      speechState.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      speechState.error!,
                      style: TextStyle(fontSize: 13, color: scheme.error),
                    ),
                  ],
                  if (showOrigin) ...[
                    const SizedBox(height: 10),
                    Text(
                      '[${languageLabel(sentence.language)} · ${sentence.category}]',
                      style: const TextStyle(
                        fontSize: 13,
                        color: DashboardPalette.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 리스트 모드 — 문장 끝 인라인 미니 오디오 버튼.
class _InlineGlassAudioButton extends StatelessWidget {
  final Color accent;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  const _InlineGlassAudioButton({
    required this.accent,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: accent,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 16,
                    color: accent,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 글래스 카드용 파스텔 원형 컨트롤 버튼.
class _GlassControlButton extends StatelessWidget {
  final Color accent;
  final double size;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  const _GlassControlButton({
    required this.accent,
    this.size = 48,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Tooltip(
            message: tooltip,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
