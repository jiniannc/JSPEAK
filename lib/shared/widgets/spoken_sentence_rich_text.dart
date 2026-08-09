import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tts_providers.dart';
import '../../app/vocabulary_providers.dart';
import '../../core/utils/cjk_spoken_feedback_spans.dart';
import '../../core/utils/cjk_stt_segments.dart';
import '../../core/utils/scenario_answer_compare.dart';
import '../../core/utils/word_compare.dart';
import '../../data/models/vocabulary_entry.dart';
import '../../data/models/vocabulary_phrase_match.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../core/utils/vocabulary_span_builder.dart';
import 'word_popup_overlay.dart';

/// 정답 문장과 STT 인식 문장을 비교해 틀린 부분만 빨간색으로 표시한다.
List<TextSpan> buildSpokenSentenceSpans({
  required String correctSentence,
  required String spokenText,
  required TextStyle baseStyle,
  String language = 'English',
  Color? correctColor,
  Color incorrectColor = Colors.red,
  Color? incorrectBackgroundColor,
  List<TapGestureRecognizer>? recognizerPool,
  VocabularyIndex? vocabulary,
  GlobalKey? anchorKey,
  BuildContext? context,
  void Function(String correctSnippet)? onTapWrongCjk,
}) {
  final resolvedCorrectColor = correctColor ?? baseStyle.color ?? Colors.black;

  if (CjkSttSegments.isTargetLanguage(language)) {
    return buildCjkSpokenFeedbackSpans(
      correctSentence: correctSentence,
      spokenText: spokenText,
      language: language,
      baseStyle: baseStyle,
      correctColor: resolvedCorrectColor,
      incorrectColor: incorrectColor,
      recognizerPool: recognizerPool,
      onTapWrong: onTapWrongCjk,
    );
  }

  final correctWords = WordCompare.splitWords(correctSentence);
  final spokenWords = WordCompare.splitWords(spokenText);
  final matches = vocabulary == null
      ? <VocabularyPhraseMatch>[]
      : VocabularySpanBuilder.findPhraseMatches(
          correctSentence,
          vocabulary.entries,
        );
  final indexMap = VocabularySpanBuilder.indexMap(matches);

  if (spokenWords.isEmpty) {
    return [TextSpan(text: spokenText, style: baseStyle)];
  }

  final spans = <TextSpan>[];
  var i = 0;

  while (i < spokenWords.length) {
    if (i > 0) {
      spans.add(TextSpan(text: ' ', style: baseStyle));
    }

    final match = i < correctWords.length ? indexMap[i] : null;
    final isMatch = WordCompare.matchesAt(spokenWords, correctWords, i);
    final color = isMatch ? resolvedCorrectColor : incorrectColor;

    if (match != null &&
        match.startIndex == i &&
        i <= match.endIndex &&
        vocabulary != null &&
        recognizerPool != null &&
        context != null &&
        anchorKey != null) {
      final end = match.endIndex.clamp(0, spokenWords.length - 1);
      final phraseText = spokenWords.sublist(i, end + 1).join(' ');

      final recognizer = TapGestureRecognizer();
      recognizerPool.add(recognizer);
      final start = match.startIndex;
      final entry = match.entry;
      recognizer.onTap = () {
        WordPopupOverlay.show(
          context: context,
          anchorKey: anchorKey,
          sentence: correctSentence,
          wordStartIndex: start,
          wordEndIndex: match.endIndex,
          textStyle: baseStyle,
          entry: entry,
        );
      };

      spans.add(
        TextSpan(
          text: phraseText,
          style: baseStyle.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: DashboardPalette.teal.withValues(alpha: 0.4),
            decorationThickness: 1.1,
          ),
          recognizer: recognizer,
        ),
      );
      i = end + 1;
      continue;
    }

    spans.add(
      TextSpan(
        text: spokenWords[i],
        style: baseStyle.copyWith(
          color: isMatch ? resolvedCorrectColor : incorrectColor,
          backgroundColor:
              !isMatch ? incorrectBackgroundColor : null,
          fontWeight: isMatch ? FontWeight.w600 : FontWeight.w700,
          decoration: !isMatch && incorrectBackgroundColor == null
              ? TextDecoration.underline
              : TextDecoration.none,
          decorationColor: incorrectColor.withValues(alpha: 0.45),
        ),
      ),
    );
    i++;
  }

  return spans;
}

/// [buildSpokenSentenceSpans]를 [RichText]로 감싼 위젯.
class SpokenSentenceRichText extends ConsumerStatefulWidget {
  final String correctSentence;
  final String spokenText;
  final String language;
  final String correctPronunciation;
  final TextStyle style;
  final Color? correctColor;
  final Color incorrectColor;
  final Color? incorrectBackgroundColor;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool enableWordLookup;
  final bool enableTapToHear;

  const SpokenSentenceRichText({
    super.key,
    required this.correctSentence,
    required this.spokenText,
    this.language = 'English',
    this.correctPronunciation = '',
    required this.style,
    this.correctColor,
    this.incorrectColor = Colors.red,
    this.incorrectBackgroundColor,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.enableWordLookup = true,
    this.enableTapToHear = false,
  });

  @override
  ConsumerState<SpokenSentenceRichText> createState() =>
      _SpokenSentenceRichTextState();
}

class _SpokenSentenceRichTextState extends ConsumerState<SpokenSentenceRichText> {
  final List<TapGestureRecognizer> _recognizers = [];
  final GlobalKey _richTextKey = GlobalKey();

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SpokenSentenceRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spokenText != widget.spokenText ||
        oldWidget.correctSentence != widget.correctSentence ||
        oldWidget.enableTapToHear != widget.enableTapToHear) {
      _disposeRecognizers();
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _speakCorrectSnippet(String snippet) {
    if (snippet.trim().isEmpty) return;
    ref.read(ttsSpeakingProvider.notifier).speakWord(
          word: snippet,
          language: widget.language,
        );
  }

  bool _hasWrongCjkSpoken() {
    if (widget.spokenText.trim().isEmpty) return false;
    final flags = ScenarioAnswerCompare.spokenCharMatchFlags(
      spoken: widget.spokenText,
      correct: widget.correctSentence,
      language: widget.language,
    );
    return flags.any((matched) => !matched);
  }

  CrossAxisAlignment _crossAxisForAlign(TextAlign align) {
    return switch (align) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.end || TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vocabulary =
        widget.enableWordLookup ? ref.watch(vocabularyProvider) : null;
    final tapToHear = widget.enableTapToHear &&
        CjkSttSegments.isTargetLanguage(widget.language);

    final children = <Widget>[
      RichText(
        key: _richTextKey,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        text: TextSpan(
          style: widget.style,
          children: buildSpokenSentenceSpans(
            correctSentence: widget.correctSentence,
            spokenText: widget.spokenText,
            language: widget.language,
            baseStyle: widget.style,
            correctColor: widget.correctColor ?? scheme.onSurface,
            incorrectColor: widget.incorrectColor,
            incorrectBackgroundColor: widget.incorrectBackgroundColor,
            recognizerPool: (widget.enableWordLookup || tapToHear)
                ? _recognizers
                : null,
            vocabulary: vocabulary,
            anchorKey: _richTextKey,
            context: widget.enableWordLookup ? context : null,
            onTapWrongCjk: tapToHear ? _speakCorrectSnippet : null,
          ),
        ),
      ),
    ];

    if (tapToHear && widget.correctPronunciation.trim().isNotEmpty) {
      children.addAll([
        const SizedBox(height: 8),
        Text(
          '정답 발음  ${widget.correctPronunciation.trim()}',
          textAlign: widget.textAlign,
          style: widget.style.copyWith(
            fontSize: (widget.style.fontSize ?? 14) * 0.82,
            fontWeight: FontWeight.w500,
            color: DashboardPalette.textMuted,
            fontStyle: FontStyle.italic,
            height: 1.3,
          ),
        ),
      ]);
    }

    if (tapToHear &&
        widget.spokenText.trim().isNotEmpty &&
        _hasWrongCjkSpoken()) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '점선 밑줄을 눌러 정발음을 들어보세요',
            textAlign: widget.textAlign,
            style: TextStyle(
              fontSize: 11,
              color: DashboardPalette.textMuted.withValues(alpha: 0.85),
              height: 1.2,
            ),
          ),
        ),
      );
    }

    if (children.length == 1) {
      return children.first;
    }

    return Column(
      crossAxisAlignment: _crossAxisForAlign(widget.textAlign),
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
