import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/word_token_alignment.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('WordTokenAligner', () {
    test('앞 단어 누락·추가가 있어도 뒤쪽 공통 단어를 매칭한다', () {
      final alignment = WordTokenAligner.alignText(
        targetText: 'This is security work',
        spokenText: "it's security work",
      );

      expect(alignment.matchedTargetCount, 2);
      expect(
        WordTokenAligner.accuracyPercent(
          targetText: 'This is security work',
          spokenText: "it's security work",
        ),
        50,
      );
    });

    test('단어 치환은 매칭으로 카운트하지 않는다', () {
      final alignment = WordTokenAligner.alignText(
        targetText: 'May I see your boarding pass?',
        spokenText: 'May I sea your boarding pass',
      );

      expect(alignment.matchedTargetCount, 5);
      expect(
        WordTokenAligner.accuracyPercent(
          targetText: 'May I see your boarding pass?',
          spokenText: 'May I sea your boarding pass',
        ),
        greaterThanOrEqualTo(80),
      );
    });

    test('완전 불일치 시 0점', () {
      expect(
        WordTokenAligner.accuracyPercent(
          targetText: 'This is security work',
          spokenText: 'hello world foo bar',
        ),
        0,
      );
    });
  });

  group('buildPronunciationInlineDiffTokens', () {
    test('LCS 정렬로 뒤쪽 일치 단어는 Match 토큰으로 유지한다', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: 'This is security work',
        spokenText: "it's security work",
      );

      expect(tokens.whereType<PronunciationInlineDiffMatch>().length, 2);
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().map((t) => t.word),
        ['security', 'work'],
      );
      expect(tokens.whereType<PronunciationInlineDiffMissing>().length, 2);
      expect(
        tokens.whereType<PronunciationInlineDiffMissing>().map((t) => t.target),
        ['This', 'is'],
      );
      expect(
        tokens.whereType<PronunciationInlineDiffCorrection>().first.spoken,
        "it's",
      );
    });

    test('정답보다 많이 말한 단어는 insertion 교정 토큰으로 표시한다', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: 'Chicken or beef',
        spokenText: 'Chicken or beef please',
      );

      expect(tokens.last, isA<PronunciationInlineDiffCorrection>());
      final correction = tokens.last as PronunciationInlineDiffCorrection;
      expect(correction.spoken, 'please');
      expect(correction.correct, isNull);
    });
  });
}
