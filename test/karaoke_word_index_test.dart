import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/answer_blank_hints.dart';
import 'package:jspeak/core/utils/karaoke_word_index.dart';

void main() {
  group('KaraokeWordIndex.resolveFromOffset', () {
    test('영어 문장은 단어 시작 오프셋으로 인덱스를 찾는다', () {
      const sentence = 'Please fasten your seatbelt.';
      expect(
        KaraokeWordIndex.resolveFromOffset(
          sentence: sentence,
          language: 'English',
          startOffset: 0,
        ),
        0,
      );
      expect(
        KaraokeWordIndex.resolveFromOffset(
          sentence: sentence,
          language: 'English',
          startOffset: 7,
        ),
        1,
      );
      expect(
        KaraokeWordIndex.resolveFromOffset(
          sentence: sentence,
          language: 'English',
          startOffset: 14,
        ),
        2,
      );
    });

    test('일본어는 글자 오프셋으로 인덱스를 찾는다', () {
      const sentence = 'お願いします';
      expect(
        KaraokeWordIndex.resolveFromOffset(
          sentence: sentence,
          language: 'Japanese',
          startOffset: 0,
        ),
        0,
      );
      expect(
        KaraokeWordIndex.resolveFromOffset(
          sentence: sentence,
          language: 'Japanese',
          startOffset: 2,
        ),
        2,
      );
    });
  });

  group('AnswerBlankHints.karaokeTokenIndexForLetter', () {
    test('영어 빈칸 슬롯은 단어 단위로 매핑된다', () {
      final letters = AnswerBlankHints.displayLetters(
        'Please fasten it.',
        language: 'English',
        blankFrame: 'Please ____ it.',
      );
      expect(
        AnswerBlankHints.karaokeTokenIndexForLetter(
          letters: letters,
          letterIndex: 0,
          language: 'English',
        ),
        0,
      );
      final fastenStart = letters.indexWhere(
        (letter) => letter.char == 'f' && letter.isKey,
      );
      expect(fastenStart, greaterThan(0));
      expect(
        AnswerBlankHints.karaokeTokenIndexForLetter(
          letters: letters,
          letterIndex: fastenStart,
          language: 'English',
        ),
        1,
      );
    });
  });
}
