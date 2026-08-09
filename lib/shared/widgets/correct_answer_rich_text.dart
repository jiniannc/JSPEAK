import 'package:flutter/material.dart';

import '../../core/utils/scenario_answer_compare.dart';
import '../../core/utils/word_compare.dart';

/// 정답 문장에서 STT와 불일치하는 단어/글자를 빨간색·취소선으로 표시.
List<TextSpan> buildCorrectAnswerHighlightSpans({
  required String correctSentence,
  required String spokenText,
  required String language,
  required TextStyle baseStyle,
  Color correctColor = Colors.black87,
  Color incorrectColor = Colors.red,
  bool useStrikethrough = true,
}) {
  if (spokenText.trim().isEmpty) {
    return [TextSpan(text: correctSentence, style: baseStyle)];
  }

  if (language == 'English') {
    return _englishSpans(
      correctSentence: correctSentence,
      spokenText: spokenText,
      baseStyle: baseStyle,
      correctColor: correctColor,
      incorrectColor: incorrectColor,
      useStrikethrough: useStrikethrough,
    );
  }

  return _cjkSpans(
    correctSentence: correctSentence,
    spokenText: spokenText,
    language: language,
    baseStyle: baseStyle,
    correctColor: correctColor,
    incorrectColor: incorrectColor,
    useStrikethrough: useStrikethrough,
  );
}

List<TextSpan> _englishSpans({
  required String correctSentence,
  required String spokenText,
  required TextStyle baseStyle,
  required Color correctColor,
  required Color incorrectColor,
  required bool useStrikethrough,
}) {
  final correctWords = WordCompare.splitWords(correctSentence);
  final flags = ScenarioAnswerCompare.wordMatchFlags(
    correct: correctSentence,
    spoken: spokenText,
    language: 'English',
  );

  if (correctWords.isEmpty) {
    return [TextSpan(text: correctSentence, style: baseStyle)];
  }

  final spans = <TextSpan>[];
  for (var i = 0; i < correctWords.length; i++) {
    if (i > 0) spans.add(TextSpan(text: ' ', style: baseStyle));
    final matched = i < flags.length && flags[i];
    spans.add(
      TextSpan(
        text: correctWords[i],
        style: baseStyle.copyWith(
          color: matched ? correctColor : incorrectColor,
          decoration: !matched && useStrikethrough
              ? TextDecoration.lineThrough
              : null,
          decorationColor: incorrectColor,
        ),
      ),
    );
  }
  return spans;
}

List<TextSpan> _cjkSpans({
  required String correctSentence,
  required String spokenText,
  required String language,
  required TextStyle baseStyle,
  required Color correctColor,
  required Color incorrectColor,
  required bool useStrikethrough,
}) {
  final flags = ScenarioAnswerCompare.wordMatchFlags(
    correct: correctSentence,
    spoken: spokenText,
    language: language,
  );
  final chars = correctSentence.split('');
  if (chars.isEmpty) {
    return [TextSpan(text: correctSentence, style: baseStyle)];
  }

  final spans = <TextSpan>[];
  for (var i = 0; i < chars.length; i++) {
    final char = chars[i];
    if (char.trim().isEmpty) {
      spans.add(TextSpan(text: char, style: baseStyle));
      continue;
    }
    final matched = i < flags.length && flags[i];
    spans.add(
      TextSpan(
        text: char,
        style: baseStyle.copyWith(
          color: matched ? correctColor : incorrectColor,
          decoration: !matched && useStrikethrough
              ? TextDecoration.lineThrough
              : null,
          decorationColor: incorrectColor,
        ),
      ),
    );
  }
  return spans;
}

class CorrectAnswerRichText extends StatelessWidget {
  final String correctSentence;
  final String spokenText;
  final String language;
  final TextStyle style;
  final Color? correctColor;
  final Color incorrectColor;
  final TextAlign textAlign;

  const CorrectAnswerRichText({
    super.key,
    required this.correctSentence,
    required this.spokenText,
    required this.language,
    required this.style,
    this.correctColor,
    this.incorrectColor = Colors.red,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: style,
        children: buildCorrectAnswerHighlightSpans(
          correctSentence: correctSentence,
          spokenText: spokenText,
          language: language,
          baseStyle: style,
          correctColor: correctColor ?? scheme.onSurface,
          incorrectColor: incorrectColor,
        ),
      ),
    );
  }
}
