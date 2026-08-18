import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/japanese_stt_fix_map.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('JapaneseSttFixMap.collapseImmediateDuplicates', () {
    test('全てのお 연속 중복을 접는다', () {
      expect(
        JapaneseSttFixMap.collapseImmediateDuplicates(
          'でございます全てのお全てのお手荷物は',
        ),
        'でございます全てのお手荷物は',
      );
    });

    test('짧은 조사 반복은 접지 않는다', () {
      expect(
        JapaneseSttFixMap.collapseImmediateDuplicates('ここ'),
        'ここ',
      );
    });
  });

  test('全てのお 중복 STT — 오답 칩 없음', () {
    const target = 'こちらは非常口座席でございます。全てのお手荷物は上の棚にお願いいたします。';
    const spoken =
        'こちらは非常口座席でございます全てのお全てのお手荷物は上の棚にお願いいたします';
    const pronunciation =
        '코치라와 히죠-구치자세키데고자이마스. 스베떼노 오테니모츠와 우에노 타나니 오네가이이타시마스.';

    final tokens = buildCjkSentenceInlineDiffTokens(
      targetText: target,
      spokenText: spoken,
      language: 'Japanese',
      koreanPronunciation: pronunciation,
    );

    expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isEmpty);
    expect(
      CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
        sentence: target,
        spokenText: spoken,
        language: 'Japanese',
      ),
      greaterThanOrEqualTo(95),
    );
  });
}
