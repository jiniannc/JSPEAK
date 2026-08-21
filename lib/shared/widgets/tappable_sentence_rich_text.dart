import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/vocabulary_providers.dart';
import '../../core/utils/word_compare.dart';
import '../../data/models/vocabulary_entry.dart';
import '../../data/models/vocabulary_phrase_match.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../core/utils/vocabulary_span_builder.dart';
import 'word_popup_overlay.dart';

TextStyle _linkStyle(TextStyle base) => base.copyWith(
      color: DashboardPalette.tealDeep,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: DashboardPalette.teal.withValues(alpha: 0.45),
      decorationThickness: 1.3,
    );

TextStyle _karaokeWordStyle(
  TextStyle base,
  int wordIndex,
  int? activeIndex,
) {
  if (activeIndex == null) return base;

  final baseColor = base.color ?? DashboardPalette.navy;
  if (wordIndex > activeIndex) {
    return base.copyWith(color: baseColor.withValues(alpha: 0.34));
  }
  if (wordIndex == activeIndex) {
    return base.copyWith(
      color: DashboardPalette.tealDeep,
      fontWeight: FontWeight.w800,
      backgroundColor: DashboardPalette.teal.withValues(alpha: 0.16),
      decoration: TextDecoration.none,
    );
  }
  return base.copyWith(color: baseColor.withValues(alpha: 0.9));
}

TextStyle _styleForWord({
  required TextStyle baseStyle,
  required int wordIndex,
  required int? karaokeWordIndex,
  required bool isVocabularyLink,
}) {
  if (karaokeWordIndex == null) {
    return isVocabularyLink ? _linkStyle(baseStyle) : baseStyle;
  }

  final karaoke = _karaokeWordStyle(baseStyle, wordIndex, karaokeWordIndex);
  if (!isVocabularyLink) return karaoke;

  if (wordIndex > karaokeWordIndex) {
    return _linkStyle(baseStyle).copyWith(
      color: (baseStyle.color ?? DashboardPalette.navy).withValues(alpha: 0.34),
      decorationColor: DashboardPalette.teal.withValues(alpha: 0.18),
    );
  }
  if (wordIndex == karaokeWordIndex) return karaoke;
  return _linkStyle(karaoke);
}

TextStyle _styleForPhrase({
  required TextStyle baseStyle,
  required int phraseStart,
  required int phraseEnd,
  required int? karaokeWordIndex,
  required bool isVocabularyLink,
}) {
  if (karaokeWordIndex == null) {
    return isVocabularyLink ? _linkStyle(baseStyle) : baseStyle;
  }

  if (karaokeWordIndex >= phraseStart && karaokeWordIndex <= phraseEnd) {
    return _karaokeWordStyle(baseStyle, karaokeWordIndex, karaokeWordIndex);
  }

  final anchor = phraseStart;
  return _styleForWord(
    baseStyle: baseStyle,
    wordIndex: anchor,
    karaokeWordIndex: karaokeWordIndex,
    isVocabularyLink: isVocabularyLink,
  );
}

/// 시트 등록 단어 탭 + 재생 가라오케 하이라이트 [TextSpan] 목록.
List<TextSpan> buildTappableWordSpans({
  required String sentence,
  required TextStyle baseStyle,
  required List<TapGestureRecognizer> recognizerPool,
  VocabularyIndex? vocabulary,
  GlobalKey? anchorKey,
  BuildContext? context,
  String language = 'English',
  int? karaokeWordIndex,
}) {
  final words = WordCompare.splitTokens(sentence, language: language);
  if (words.isEmpty) {
    return [TextSpan(text: sentence, style: baseStyle)];
  }

  final matches = vocabulary == null
      ? <VocabularyPhraseMatch>[]
      : VocabularySpanBuilder.findPhraseMatches(
          sentence,
          vocabulary.entries,
          language: language,
        );
  final indexMap = VocabularySpanBuilder.indexMap(matches);
  final spans = <TextSpan>[];
  final separator = WordCompare.tokenSeparator(language);

  var i = 0;
  while (i < words.length) {
    if (i > 0 && separator.isNotEmpty) {
      spans.add(
        TextSpan(
          text: separator,
          style: _karaokeWordStyle(baseStyle, i - 1, karaokeWordIndex),
        ),
      );
    }

    final match = indexMap[i];
    if (match != null && match.startIndex == i) {
      final phraseText = words
          .sublist(match.startIndex, match.endIndex + 1)
          .join(separator);

      TapGestureRecognizer? recognizer;
      if (context != null && anchorKey != null) {
        recognizer = TapGestureRecognizer();
        recognizerPool.add(recognizer);
        final start = match.startIndex;
        final end = match.endIndex;
        final entry = match.entry;
        recognizer.onTap = () {
          WordPopupOverlay.show(
            context: context,
            anchorKey: anchorKey,
            sentence: sentence,
            wordStartIndex: start,
            wordEndIndex: end,
            textStyle: baseStyle,
            entry: entry,
            language: language,
          );
        };
      }

      spans.add(
        TextSpan(
          text: phraseText,
          style: _styleForPhrase(
            baseStyle: baseStyle,
            phraseStart: match.startIndex,
            phraseEnd: match.endIndex,
            karaokeWordIndex: karaokeWordIndex,
            isVocabularyLink: true,
          ),
          recognizer: recognizer,
        ),
      );
      i = match.endIndex + 1;
      continue;
    }

    spans.add(
      TextSpan(
        text: words[i],
        style: _styleForWord(
          baseStyle: baseStyle,
          wordIndex: i,
          karaokeWordIndex: karaokeWordIndex,
          isVocabularyLink: false,
        ),
      ),
    );
    i++;
  }

  return spans;
}

/// 문장의 시트 등록 단어만 탭하면 미니 팝업을 띄우는 [RichText].
class TappableSentenceRichText extends ConsumerStatefulWidget {
  final String sentence;
  final String language;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  /// 재생 중 하이라이트할 단어 인덱스. null이면 가라오케 비활성.
  final int? karaokeWordIndex;

  const TappableSentenceRichText({
    super.key,
    required this.sentence,
    this.language = 'English',
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.karaokeWordIndex,
  });

  @override
  ConsumerState<TappableSentenceRichText> createState() =>
      _TappableSentenceRichTextState();
}

class _TappableSentenceRichTextState
    extends ConsumerState<TappableSentenceRichText> {
  final List<TapGestureRecognizer> _recognizers = [];
  final GlobalKey _richTextKey = GlobalKey();

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TappableSentenceRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentence != widget.sentence) {
      _disposeRecognizers();
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vocabulary = ref.watch(vocabularyProvider);

    final spans = buildTappableWordSpans(
      sentence: widget.sentence,
      baseStyle: widget.style,
      recognizerPool: _recognizers,
      vocabulary: vocabulary,
      anchorKey: _richTextKey,
      context: context,
      language: widget.language,
      karaokeWordIndex: widget.karaokeWordIndex,
    );

    return RichText(
      key: _richTextKey,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      text: TextSpan(style: widget.style, children: spans),
    );
  }
}
