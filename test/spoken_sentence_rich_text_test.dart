import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/word_compare.dart';
import 'package:jspeak/shared/widgets/spoken_sentence_rich_text.dart';

void main() {
  group('WordCompare', () {
    test('문장부호와 대소문자를 무시하고 비교한다', () {
      expect(WordCompare.normalize('Hello,'), 'hello');
      expect(WordCompare.normalize('WORLD!'), 'world');
      expect(
        WordCompare.matchesAt(
          ['hello,', 'world!'],
          ['Hello', 'world'],
          0,
        ),
        isTrue,
      );
      expect(
        WordCompare.matchesAt(
          ['hello,', 'word!'],
          ['Hello', 'world'],
          1,
        ),
        isFalse,
      );
    });

    test('연속 공백은 빈 토큰 없이 분리한다', () {
      expect(
        WordCompare.splitWords('May  I   see'),
        ['May', 'I', 'see'],
      );
    });
  });

  group('buildSpokenSentenceSpans', () {
    test('일치 단어는 기본 색, 불일치는 빨간색으로 표시한다', () {
      const baseStyle = TextStyle(color: Color(0xFF001A33));
      final spans = buildSpokenSentenceSpans(
        correctSentence: 'May I see your boarding pass?',
        spokenText: 'May I sea your boarding pass',
        baseStyle: baseStyle,
      );

      expect(spans.length, 11);
      expect(spans[0].text, 'May');
      expect(spans[0].style?.color, const Color(0xFF001A33));
      expect(spans[4].text, 'sea');
      expect(spans[4].style?.color, Colors.red);
    });

    test('정답보다 많이 말한 단어는 빨간색으로 표시한다', () {
      const baseStyle = TextStyle(color: Colors.black);
      final spans = buildSpokenSentenceSpans(
        correctSentence: 'Chicken or beef',
        spokenText: 'Chicken or beef please',
        baseStyle: baseStyle,
      );

      expect(spans.last.text, 'please');
      expect(spans.last.style?.color, Colors.red);
    });
  });
}
