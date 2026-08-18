import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/core/utils/japanese_reading_fold.dart';
import 'package:jspeak/core/utils/japanese_to_korean_converter.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  const target = 'ベビーカーは、搭乗前に折り畳んでください。';
  const spoken = 'ベビーカーは搭乗前に折りたたんでください';
  const pronunciation = '베비-카-와 토-죠-마에니 오리타탄^데쿠다사이.';

  group('折り畳む — STT 히라가나 たた vs 정답 한자 畳', () {
    test('한자 읽기 사전에 畳=たた 등록', () {
      expect(JapaneseToKoreanConverter.toHiragana('畳'), 'たた');
      expect(JapaneseToKoreanConverter.toHiragana('折り畳'), 'おりたた');
    });

    test('reading fold가 たた를 畳으로 접는다', () {
      final strippedTarget = target.replaceAll(RegExp(r'[。、！？，,\.!?]'), '');
      final strippedSpoken = spoken.replaceAll(RegExp(r'[。、！？，,\.!?]'), '');
      expect(
        JapaneseReadingFold.fold(strippedSpoken, strippedTarget),
        strippedTarget,
      );
    });

    test('오답 칩 없이 100점', () {
      expect(
        pronunciationHasWordDiff(
          targetText: target,
          spokenText: spoken,
          language: 'Japanese',
          koreanPronunciation: pronunciation,
        ),
        isFalse,
      );
      expect(
        pronunciationIsTextPerfectMatch(
          targetText: target,
          spokenText: spoken,
          language: 'Japanese',
          koreanPronunciation: pronunciation,
        ),
        isTrue,
      );
      expect(
        CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
          sentence: target,
          spokenText: spoken,
          language: 'Japanese',
        ),
        100,
      );
    });
  });
}
