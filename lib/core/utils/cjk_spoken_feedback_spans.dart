import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'cjk_stt_segments.dart';
import 'scenario_answer_compare.dart';

/// CJK 인덱스 구간에 대응하는 정답 문장 일부 (TTS 재생용).
String correctSnippetForCjkRange({
  required int cjkStart,
  required int cjkEnd,
  required String correctSentence,
}) {
  final chars = correctSentence.split('');
  if (chars.isEmpty || cjkStart >= chars.length) return correctSentence;
  final end = cjkEnd.clamp(0, chars.length);
  if (cjkStart >= end) return chars[cjkStart];
  return chars.sublist(cjkStart, end).join();
}

/// STT에 섞인 발음표기(로마字·병음 등)와 대상 문자를 구분해 표시용 [TextSpan] 생성.
List<TextSpan> buildCjkSpokenFeedbackSpans({
  required String correctSentence,
  required String spokenText,
  required String language,
  required TextStyle baseStyle,
  Color? correctColor,
  Color incorrectColor = Colors.red,
  List<TapGestureRecognizer>? recognizerPool,
  void Function(String correctSnippet)? onTapWrong,
}) {
  final resolvedCorrectColor = correctColor ?? baseStyle.color ?? Colors.black;

  if (spokenText.trim().isEmpty) {
    return [TextSpan(text: spokenText, style: baseStyle)];
  }

  final displaySpoken = language == 'Japanese'
      ? ScenarioAnswerCompare.preprocessSpoken(
          spokenText,
          language: language,
        )
      : spokenText;

  final flags = ScenarioAnswerCompare.spokenCharMatchFlags(
    spoken: spokenText,
    correct: correctSentence,
    language: language,
  );

  final segments = CjkSttSegments.parse(displaySpoken, language);
  final spans = <TextSpan>[];
  var cjkIndex = 0;

  final pronStyle = baseStyle.copyWith(
    fontSize: (baseStyle.fontSize ?? 14) * 0.88,
    color: (baseStyle.color ?? Colors.black).withValues(alpha: 0.5),
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    height: baseStyle.height,
  );

  for (final segment in segments) {
    if (!segment.isTargetScript) {
      spans.add(TextSpan(text: segment.text, style: pronStyle));
      continue;
    }

    var local = 0;
    while (local < segment.text.length) {
      final globalIdx = cjkIndex + local;
      final isMatch = globalIdx < flags.length && flags[globalIdx];

      var runEnd = local + 1;
      while (runEnd < segment.text.length) {
        final nextIdx = cjkIndex + runEnd;
        final nextMatch = nextIdx < flags.length && flags[nextIdx];
        if (nextMatch != isMatch) break;
        runEnd++;
      }

      final runText = segment.text.substring(local, runEnd);
      final canTap = !isMatch &&
          onTapWrong != null &&
          recognizerPool != null &&
          runText.trim().isNotEmpty;

      if (canTap) {
        final snippet = correctSnippetForCjkRange(
          cjkStart: globalIdx,
          cjkEnd: cjkIndex + runEnd,
          correctSentence: correctSentence,
        );
        final recognizer = TapGestureRecognizer()
          ..onTap = () => onTapWrong(snippet);
        recognizerPool.add(recognizer);
        spans.add(
          TextSpan(
            text: runText,
            style: baseStyle.copyWith(
              color: incorrectColor,
              decoration: TextDecoration.underline,
              decorationColor: incorrectColor.withValues(alpha: 0.65),
              decorationStyle: TextDecorationStyle.dotted,
              decorationThickness: 1.2,
            ),
            recognizer: recognizer,
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: runText,
            style: baseStyle.copyWith(
              color: isMatch ? resolvedCorrectColor : incorrectColor,
              decoration: !isMatch && runText.trim().isNotEmpty
                  ? TextDecoration.lineThrough
                  : null,
              decorationColor: incorrectColor,
            ),
          ),
        );
      }

      local = runEnd;
    }
    cjkIndex += segment.text.length;
  }

  return spans;
}
