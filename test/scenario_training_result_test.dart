import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/data/models/scenario_training_result.dart';

void main() {
  group('ScenarioTrainingResult scoring', () {
    test('힌트 없는 녹음 첫 통과는 100점', () {
      const turn = ScenarioTurnPerformance(
        lineOrder: 1,
        voiceAttempts: 1,
        keyboardAttempts: 0,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.voice,
      );

      expect(turn.score, 100);
      expect(
        const ScenarioTrainingResult(turns: [turn]).grade,
        ScenarioPerformanceGrade.s,
      );
    });

    test('녹음 재시도와 힌트 사용은 단계적으로 감점', () {
      const secondTry = ScenarioTurnPerformance(
        lineOrder: 1,
        voiceAttempts: 2,
        keyboardAttempts: 0,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.voice,
      );
      const structureHint = ScenarioTurnPerformance(
        lineOrder: 2,
        voiceAttempts: 1,
        keyboardAttempts: 0,
        hintLevel: 1,
        resolutionMethod: ScenarioResolutionMethod.voice,
      );
      const wordHint = ScenarioTurnPerformance(
        lineOrder: 3,
        voiceAttempts: 1,
        keyboardAttempts: 0,
        hintLevel: 2,
        resolutionMethod: ScenarioResolutionMethod.voice,
      );

      expect(secondTry.score, 93);
      expect(structureHint.score, 92);
      expect(wordHint.score, 83);
    });

    test('키보드 통과는 녹음 참여 여부를 별도로 반영', () {
      const keyboardOnly = ScenarioTurnPerformance(
        lineOrder: 1,
        voiceAttempts: 0,
        keyboardAttempts: 1,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.keyboard,
      );
      const triedVoiceFirst = ScenarioTurnPerformance(
        lineOrder: 2,
        voiceAttempts: 1,
        keyboardAttempts: 1,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.keyboard,
      );

      expect(keyboardOnly.score, 55);
      expect(triedVoiceFirst.score, 65);
    });

    test('정답 확인 시 해당 턴은 모든 항목 0점', () {
      const turn = ScenarioTurnPerformance(
        lineOrder: 1,
        voiceAttempts: 3,
        keyboardAttempts: 2,
        hintLevel: 2,
        resolutionMethod: ScenarioResolutionMethod.answerReveal,
      );

      expect(turn.score, 0);
    });

    test('집계 비율은 시각화용으로 일관되게 계산된다', () {
      const voice = ScenarioTurnPerformance(
        lineOrder: 1,
        voiceAttempts: 1,
        keyboardAttempts: 0,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.voice,
      );
      const keyboard = ScenarioTurnPerformance(
        lineOrder: 2,
        voiceAttempts: 0,
        keyboardAttempts: 1,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.keyboard,
      );
      const result = ScenarioTrainingResult(turns: [voice, keyboard]);

      expect(result.voicePassRatio, 0.5);
      expect(result.keyboardResolutionRatio, 0.5);
      expect(result.efficiencyRatio, 1.0);
      expect(result.speakingParticipationRatio, 0.5);
      expect(result.hintFreeRatio, 1.0);
    });

    test('힌트 링은 대사당 2회 슬롯 기준으로 계산된다', () {
      const hintedOnce = ScenarioTurnPerformance(
        lineOrder: 1,
        voiceAttempts: 1,
        keyboardAttempts: 0,
        hintLevel: 1,
        resolutionMethod: ScenarioResolutionMethod.voice,
      );
      const clean = ScenarioTurnPerformance(
        lineOrder: 2,
        voiceAttempts: 1,
        keyboardAttempts: 0,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.voice,
      );
      const result = ScenarioTrainingResult(
        turns: [hintedOnce, clean, clean],
      );

      expect(result.totalHintSlots, 6);
      expect(result.totalHintsUsed, 1);
      expect(result.hintFreeRatio, closeTo(5 / 6, 0.001));
    });

    test('전체 점수는 승무원 대사별 점수의 평균', () {
      const perfect = ScenarioTurnPerformance(
        lineOrder: 1,
        voiceAttempts: 1,
        keyboardAttempts: 0,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.voice,
      );
      const keyboard = ScenarioTurnPerformance(
        lineOrder: 2,
        voiceAttempts: 0,
        keyboardAttempts: 1,
        hintLevel: 0,
        resolutionMethod: ScenarioResolutionMethod.keyboard,
      );
      const result = ScenarioTrainingResult(turns: [perfect, keyboard]);

      expect(result.score, 78);
      expect(result.grade, ScenarioPerformanceGrade.b);
      expect(result.voicePassedTurns, 1);
      expect(result.keyboardPassedTurns, 1);
    });
  });
}
