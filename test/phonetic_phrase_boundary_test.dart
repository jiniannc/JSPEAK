import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('구문 발음 경계 — 옆 단어 발음이 섞여 들어오지 않는다', () {
    test(
      'を 뒤가 히라가나라 세그멘테이션이 문장 전체를 한 구문으로 뭉쳐도, '
      'pronunciation 공백을 이용해 구문을 다시 나눈다',
      () {
        const sentence = 'ご搭乗券をお願いいたします。';
        const pronunciation = '고토-죠-켕^오 오네가이이타시마스.';

        final lexicon = CjkPronunciationPhraseBuilder.buildLexicon(
          sentence: sentence,
          pronunciation: pronunciation,
          language: 'Japanese',
        );

        expect(lexicon.length, 2);
        expect(lexicon[0].surface, 'ご搭乗券を');
        expect(lexicon[1].surface, 'お願いいたします。');
      },
    );

    test('記号(오인식) 정정 칩 — 券を 실제 발음이 옆 단어로 새지 않는다', () {
      const target = 'ご搭乗券をお願いいたします。';
      const spoken = 'ご搭乗記号お願いいたします';
      const pronunciation = '고토-죠-켕^오 오네가이이타시마스.';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      final match = tokens.whereType<PronunciationInlineDiffMatch>().first;
      // 「ご搭乗」의 발음에 다음 단어 「券」의 음절(켕)이 섞이면 안 된다.
      expect(match.word, 'ご搭乗');
      expect(match.phonetic, isNot(contains('켕')));

      final correction =
          tokens.whereType<PronunciationInlineDiffCorrection>().first;
      expect(correction.correct, '券を');
      // 정답 발음은 완전한 「켕오」를 유지해야 한다.
      expect(correction.correctPhonetic, contains('켕'));
      // 실제로 들린(오인식) 발음도 표시되어야 한다 — 「記号」= 키고우.
      expect(correction.spokenPhonetic, isNotNull);
      expect(correction.spokenPhonetic, isNot(''));
    });
  });
}
