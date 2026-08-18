import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/core/utils/cjk_stt_segments.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  test('々(한자 반복부호)는 목표 문자로 인식된다', () {
    expect(CjkSttSegments.isTargetChar('々'), isTrue);
  });

  test('extractTargetScript가 々을 지우지 않는다', () {
    expect(
      CjkSttSegments.extractTargetScript('色々なスナックを', 'Japanese'),
      '色々なスナックを',
    );
  });

  test('色々 완전 일치 발음 — 々 때문에 Missing/오답으로 오판되지 않고 100점', () {
    const target = '色々な スナックを 販売いたしております。';
    const spoken = '色々なスナックを販売いたしております';
    const pronunciation = '이로이로나 스낙^꾸오 함^바이이타시테오리마스.';

    final tokens = buildCjkSentenceInlineDiffTokens(
      targetText: target,
      spokenText: spoken,
      language: 'Japanese',
      koreanPronunciation: pronunciation,
    );

    expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isEmpty);
    expect(tokens.whereType<PronunciationInlineDiffMissing>(), isEmpty);

    final score = CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
      sentence: target,
      spokenText: spoken,
      language: 'Japanese',
    );
    expect(score, 100);
  });
}
