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

/// 시트에 등록된 단어/구문만 연속 밑줄 + 탭 팝업 [TextSpan] 목록.
List<TextSpan> buildTappableWordSpans({
  required String sentence,
  required TextStyle baseStyle,
  required List<TapGestureRecognizer> recognizerPool,
  VocabularyIndex? vocabulary,
  GlobalKey? anchorKey,
  BuildContext? context,
  String language = 'English',
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
      spans.add(TextSpan(text: separator, style: baseStyle));
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
          style: _linkStyle(baseStyle),
          recognizer: recognizer,
        ),
      );
      i = match.endIndex + 1;
      continue;
    }

    spans.add(TextSpan(text: words[i], style: baseStyle));
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

  const TappableSentenceRichText({
    super.key,
    required this.sentence,
    this.language = 'English',
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
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
