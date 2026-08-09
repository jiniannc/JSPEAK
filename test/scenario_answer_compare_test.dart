import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/answer_blank_hints.dart';
import 'package:jspeak/core/utils/scenario_answer_compare.dart';

void main() {
  group('ScenarioAnswerCompare CJK inclusion', () {
    test('STT 보정 맵: 後藤直近 → ご搭乗券 치환 후 고득점', () {
      const correct = 'ご搭乗券をお願いいたします';
      const spoken = '後藤直近をお願いいたします';
      const language = 'Japanese';

      final percent = ScenarioAnswerCompare.similarityPercent(
        spoken: spoken,
        correct: correct,
        language: language,
      );
      expect(percent, greaterThanOrEqualTo(90));

      expect(
        ScenarioAnswerCompare.isCorrect(
          spoken: spoken,
          correct: correct,
          language: language,
        ),
        isTrue,
      );
    });

    test('wordMatchFlags: 보정 전에는 뒤쪽만, 보정 후에는 전체 일치', () {
      const correct = 'ご搭乗券をお願いいたします';
      const spoken = '後藤直近をお願いいたします';
      const language = 'Japanese';

      final flags = ScenarioAnswerCompare.wordMatchFlags(
        correct: correct,
        spoken: spoken,
        language: language,
      );
      final percent = ScenarioAnswerCompare.similarityPercent(
        spoken: spoken,
        correct: correct,
        language: language,
      );

      expect(percent, greaterThanOrEqualTo(90));

      final correctChars = correct.split('');
      final woIndex = correctChars.indexOf('を');
      for (var i = woIndex; i < correctChars.length; i++) {
        if (correctChars[i].trim().isEmpty) continue;
        expect(flags[i], isTrue, reason: 'suffix ${correctChars[i]}');
      }
    });

    test('일본어 한자/히라가나 혼용도 정답 처리', () {
      expect(
        ScenarioAnswerCompare.isCorrect(
          spoken: 'お願い致します',
          correct: 'お願いいたします',
          language: 'Japanese',
        ),
        isTrue,
      );

      final flags = ScenarioAnswerCompare.wordMatchFlags(
        correct: 'お願いいたします',
        spoken: 'お願い致します',
        language: 'Japanese',
      );
      final matched = flags.where((f) => f).length;
      expect(matched, greaterThanOrEqualTo(8));
    });

    test('AnswerBlankHints도 포함 관계로 뒤쪽 글자 누적 반영', () {
      const correct = 'ご搭乗券をお願いいたします';
      const spoken = '後藤直近をお願いいたします';
      const language = 'Japanese';

      final states = AnswerBlankHints.letterStates(
        correct: correct,
        spoken: spoken,
        language: language,
      );
      final letters = AnswerBlankHints.displayLetters(
        correct,
        language: language,
      );

      var correctCount = 0;
      for (var i = 0; i < letters.length; i++) {
        if (letters[i].isGap) continue;
        if (states[i].kind == BlankRevealKind.correct) correctCount++;
      }
      expect(correctCount, greaterThan(5));
    });
  });
}
