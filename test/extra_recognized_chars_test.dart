import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';

void main() {
  group('CjkPronunciationPhraseBuilder.extraRecognizedChars', () {
    test('완전 일치면 초과 글자가 없다', () {
      const target = 'ご搭乗券をお願いいたします。';
      const spoken = 'ご搭乗券をお願いいたします';

      expect(
        CjkPronunciationPhraseBuilder.extraRecognizedChars(
          sentence: target,
          spokenText: spoken,
          language: 'Japanese',
        ),
        isEmpty,
      );
    });

    test('STT가 잡음으로 여분의 글자를 더 인식하면 그 글자를 짚어낸다', () {
      const target = 'ありがとうございます。';
      const spoken = 'ありがとうございますんん';

      final extra = CjkPronunciationPhraseBuilder.extraRecognizedChars(
        sentence: target,
        spokenText: spoken,
        language: 'Japanese',
      );

      expect(extra, isNotEmpty);
      expect(extra, everyElement('ん'));

      final score = CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
        sentence: target,
        spokenText: spoken,
        language: 'Japanese',
      );
      expect(score, lessThan(100));
    });
  });
}
