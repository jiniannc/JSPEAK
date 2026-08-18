import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/core/utils/japanese_number_normalizer.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('JapaneseNumberNormalizer', () {
    test('110 → ひゃくじゅう, 70 → ななじゅう', () {
      expect(
        JapaneseNumberNormalizer.expandDigitsInText('上が110、下が70'),
        '上がひゃくじゅう、下がななじゅう',
      );
    });

    test('expandWithMap — 원문 숫자 구간 역매핑', () {
      const original = '上が110、下が70';
      final exp = JapaneseNumberNormalizer.expandWithMap(original);
      expect(exp.expanded, '上がひゃくじゅう、下がななじゅう');
      expect(
        JapaneseNumberNormalizer.originalSliceForExpandedRange(
          exp,
          exp.expanded.indexOf('ひ'),
          exp.expanded.indexOf('う') + 1,
        ),
        '110',
      );
      expect(
        JapaneseNumberNormalizer.originalSliceForExpandedRange(
          exp,
          exp.expanded.indexOf('な'),
          exp.expanded.indexOf('う', exp.expanded.indexOf('な')) + 1,
        ),
        '70',
      );
    });
  });

  group('혈압 문장 숫자 채점', () {
    const target = '血圧は上が110、下が70で、少し低めです。';
    const pron =
        '케츠아츠와 우에가 햐쿠쥬-, 시타가 나나쥬-데, 스코시 히쿠메데스.';

    test('STT가 아라비아 숫자로 반환해도 만점', () {
      final score = CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
        sentence: target,
        spokenText: '血圧は上が110下が70で少し低めです',
        language: 'Japanese',
      );
      expect(score, 100);
    });

    test('STT가 히라가나 숫자로 반환해도 만점', () {
      final score = CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
        sentence: target,
        spokenText: '血圧は上がひゃくじゅう下がななじゅうで少し低めです',
        language: 'Japanese',
      );
      expect(score, 100);
    });

    test('diff — 숫자 구간 오답 표시 없음', () {
      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: '血圧は上が110下が70で少し低めです',
        language: 'Japanese',
        koreanPronunciation: pron,
      );
      expect(
        tokens.whereType<PronunciationInlineDiffCorrection>(),
        isEmpty,
      );
    });
  });
}
