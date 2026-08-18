import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/core/utils/japanese_to_korean_converter.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('QR mixed Japanese sentence', () {
    const target = 'QRコードをスキャンしております';
    const spoken = 'コードをスキャンしております';
    const pronunciation = '큐-아-루 코-도오 스캔시테 오리마스';

    test('spoken surface converts to hangul, not QR', () {
      final result = JapaneseToKoreanConverter.transliterateOrNull(spoken);
      expect(result, isNotNull);
      expect(result, isNot('QR'));
      expect(result, isNot(contains('QR')));
    });

    test('QR acronym maps to hangul', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('QR'),
        '큐-아-루',
      );
    });

    test('QRコード mixed token converts fully', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('QRコード'),
        contains('큐-아-루'),
      );
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('QRコード'),
        isNot(contains('QR')),
      );
    });

    test('wrong chip spokenPhonetic uses STT conversion only', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      final corrections = tokens.whereType<PronunciationInlineDiffCorrection>();
      final missing = tokens.whereType<PronunciationInlineDiffMissing>();
      expect(corrections.isNotEmpty || missing.isNotEmpty, isTrue);

      for (final c in corrections) {
        expect(c.spokenPhonetic, isNotNull);
        expect(c.spokenPhonetic, isNot('QR'));
        expect(c.spokenPhonetic, isNot(contains('QR')));
        expect(c.spokenPhonetic, isNot(contains('큐-아-루')));
      }
    });

    test('STT with latin QR prefix does not leak QR into wrong phonetic', () {
      const spokenWithQr = 'QRコードをスキャンしております';
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spokenWithQr,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      for (final c in tokens.whereType<PronunciationInlineDiffCorrection>()) {
        expect(c.spokenPhonetic, isNot('QR'));
        expect(c.spokenPhonetic, isNot(contains('QR')));
      }
    });

    test('STT with latin QR prefix scores higher', () {
      const spokenWithQr = 'QRコードをスキャンしております';
      final scoreWithQr = CjkPronunciationPhraseBuilder.accuracyPercent(
        sentence: target,
        pronunciation: pronunciation,
        spokenText: spokenWithQr,
        language: 'Japanese',
      );
      final scoreWithoutQr = CjkPronunciationPhraseBuilder.accuracyPercent(
        sentence: target,
        pronunciation: pronunciation,
        spokenText: spoken,
        language: 'Japanese',
      );
      expect(scoreWithQr, greaterThan(scoreWithoutQr));
      expect(scoreWithQr, 100);
    });

    test('partial score remains non-zero when QR missing', () {
      final score = CjkPronunciationPhraseBuilder.accuracyPercent(
        sentence: target,
        pronunciation: pronunciation,
        spokenText: spoken,
        language: 'Japanese',
      );
      expect(score, greaterThanOrEqualTo(70));
      expect(score, lessThan(100));
    });
  });
}
