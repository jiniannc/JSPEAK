import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_spoken_phonetic.dart';
import 'package:jspeak/core/utils/hanzi_to_pinyin_converter.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('HanziToPinyinConverter', () {
    test('STT 오답 한자를 성조 병음으로 변환', () {
      expect(
        HanziToPinyinConverter.transliterateOrNull('欢迎当机'),
        'huān yíng dāng jī',
      );
    });
  });

  group('Chinese wrong chip pinyin', () {
    const target = '欢迎登机';
    const spoken = '欢迎当机';
    const pronunciation = 'huān yíng dēng jī';

    test('오답 칩 spokenPhonetic에 성조 병음 포함', () {
      expect(
        CjkSpokenPhonetic.phoneticForSpokenSurface(
          spoken,
          language: 'Chinese',
        ),
        'huān yíng dāng jī',
      );
    });

    test('diff 토큰 오답 칩에 병음 매핑', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Chinese',
        koreanPronunciation: pronunciation,
      );

      final corrections = tokens.whereType<PronunciationInlineDiffCorrection>();
      expect(corrections, isNotEmpty);

      for (final c in corrections) {
        if (c.spoken.contains('当机')) {
          expect(c.spokenPhonetic, isNotNull);
          expect(c.spokenPhonetic, contains('dāng'));
          expect(c.spokenPhonetic, contains('jī'));
        }
      }
    });
  });
}
