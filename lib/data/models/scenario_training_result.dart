enum ScenarioResolutionMethod { voice, keyboard, answerReveal }

class ScenarioTurnPerformance {
  final int lineOrder;
  final int voiceAttempts;
  final int keyboardAttempts;
  final int hintLevel;
  final ScenarioResolutionMethod resolutionMethod;

  const ScenarioTurnPerformance({
    required this.lineOrder,
    required this.voiceAttempts,
    required this.keyboardAttempts,
    required this.hintLevel,
    required this.resolutionMethod,
  });

  bool get usedVoice => voiceAttempts > 0;
  bool get passedByVoice =>
      resolutionMethod == ScenarioResolutionMethod.voice;
  bool get passedByKeyboard =>
      resolutionMethod == ScenarioResolutionMethod.keyboard;
  bool get revealedAnswer =>
      resolutionMethod == ScenarioResolutionMethod.answerReveal;
  bool get firstTryVoice => passedByVoice && voiceAttempts == 1;

  int get efficiencyScore => switch (resolutionMethod) {
        ScenarioResolutionMethod.voice => switch (voiceAttempts) {
            <= 1 => 30,
            2 => 23,
            3 => 16,
            _ => 10,
          },
        ScenarioResolutionMethod.keyboard => switch (keyboardAttempts) {
            <= 1 => 15,
            2 => 10,
            _ => 6,
          },
        ScenarioResolutionMethod.answerReveal => 0,
      };

  int get maxEfficiencyScore => switch (resolutionMethod) {
        ScenarioResolutionMethod.voice => 30,
        ScenarioResolutionMethod.keyboard => 15,
        ScenarioResolutionMethod.answerReveal => 0,
      };

  int get score {
    if (revealedAnswer) return 0;

    final resolution = switch (resolutionMethod) {
      ScenarioResolutionMethod.voice => 35,
      ScenarioResolutionMethod.keyboard => 15,
      ScenarioResolutionMethod.answerReveal => 0,
    };
    final efficiency = efficiencyScore;
    final independence = switch (hintLevel.clamp(0, 3)) {
      0 => 25,
      1 => 20,
      2 => 14,
      _ => 8,
    };
    final speakingParticipation = usedVoice ? 10 : 0;
    return (resolution + efficiency + independence + speakingParticipation)
        .clamp(0, 100);
  }
}

enum ScenarioPerformanceGrade { s, a, b, c, d }

class ScenarioTrainingResult {
  final List<ScenarioTurnPerformance> turns;

  const ScenarioTrainingResult({required this.turns});

  int get score {
    if (turns.isEmpty) return 0;
    return (turns.fold<int>(0, (sum, turn) => sum + turn.score) /
            turns.length)
        .round()
        .clamp(0, 100);
  }

  ScenarioPerformanceGrade get grade => switch (score) {
        >= 95 => ScenarioPerformanceGrade.s,
        >= 85 => ScenarioPerformanceGrade.a,
        >= 70 => ScenarioPerformanceGrade.b,
        >= 55 => ScenarioPerformanceGrade.c,
        _ => ScenarioPerformanceGrade.d,
      };

  int get totalTurns => turns.length;
  int get voicePassedTurns => turns.where((turn) => turn.passedByVoice).length;
  int get keyboardPassedTurns =>
      turns.where((turn) => turn.passedByKeyboard).length;
  int get firstTryVoiceTurns =>
      turns.where((turn) => turn.firstTryVoice).length;
  int get totalVoiceAttempts =>
      turns.fold(0, (sum, turn) => sum + turn.voiceAttempts);
  int get totalKeyboardAttempts =>
      turns.fold(0, (sum, turn) => sum + turn.keyboardAttempts);
  int get audioHintUses =>
      turns.where((turn) => turn.hintLevel >= 1).length;
  int get structureHintUses =>
      turns.where((turn) => turn.hintLevel >= 2).length;
  int get wordHintUses =>
      turns.where((turn) => turn.hintLevel >= 3).length;
  int get answerRevealUses =>
      turns.where((turn) => turn.revealedAnswer).length;

  /// 대사당 오디오·구조·단어 힌트 3회.
  static const hintsPerTurn = 3;

  int get totalHintSlots => turns.length * hintsPerTurn;

  int get totalHintsUsed => turns.fold(
        0,
        (sum, turn) => sum + turn.hintLevel.clamp(0, hintsPerTurn),
      );

  double get voicePassRatio =>
      totalTurns == 0 ? 0 : voicePassedTurns / totalTurns;

  double get keyboardResolutionRatio =>
      totalTurns == 0 ? 0 : keyboardPassedTurns / totalTurns;

  double get answerRevealRatio =>
      totalTurns == 0 ? 0 : answerRevealUses / totalTurns;

  /// 시도 횟수 효율 — 턴별 최대 efficiency 대비 평균 (0~1).
  double get efficiencyRatio {
    if (turns.isEmpty) return 0;
    var sum = 0.0;
    var count = 0;
    for (final turn in turns) {
      final max = turn.maxEfficiencyScore;
      if (max <= 0) continue;
      sum += turn.efficiencyScore / max;
      count++;
    }
    if (count == 0) return 0;
    return (sum / count).clamp(0.0, 1.0);
  }

  /// 녹음을 한 번이라도 시도한 대사 비율 (0~1). 정답 확인 턴은 제외.
  double get speakingParticipationRatio {
    if (turns.isEmpty) return 0;
    return turns.where((turn) => turn.usedVoice && !turn.revealedAnswer).length /
        turns.length;
  }

  /// 사용하지 않은 힌트 슬롯 비율 (0~1). 대사당 힌트 3회 기준.
  double get hintFreeRatio {
    if (turns.isEmpty || totalHintSlots <= 0) return 0;
    return ((totalHintSlots - totalHintsUsed) / totalHintSlots)
        .clamp(0.0, 1.0);
  }

  String get gradeTitle => switch (grade) {
        ScenarioPerformanceGrade.s => 'CABIN MASTER',
        ScenarioPerformanceGrade.a => 'FIRST CLASS CREW',
        ScenarioPerformanceGrade.b => 'READY FOR SERVICE',
        ScenarioPerformanceGrade.c => 'REHEARSAL NEEDED',
        ScenarioPerformanceGrade.d => 'RETRY BOARDING',
      };

  String get gradeMedal => switch (grade) {
        ScenarioPerformanceGrade.s => '👑',
        ScenarioPerformanceGrade.a => '💎',
        ScenarioPerformanceGrade.b => '🥇',
        ScenarioPerformanceGrade.c => '🥈',
        ScenarioPerformanceGrade.d => '🎫',
      };

  String get coachingComment {
    if (score >= 95 &&
        voicePassedTurns == totalTurns &&
        structureHintUses == 0 &&
        audioHintUses == 0) {
      return '힌트 없이 한 번에 완벽하게 응대했어요. 다음 시나리오로 넘어가 볼까요?';
    }
    if (answerRevealUses > 0) {
      return '정답을 확인한 대사를 집중 복습하면, 다음 도전에서 점수가 크게 오를 거예요.';
    }
    if (voicePassRatio < 0.5) {
      return '내용은 잘 알고 있어요. 이번에는 목소리로 다시 응대해 보세요!';
    }
    if (wordHintUses > 0 || structureHintUses > totalTurns / 2) {
      return '힌트 의존도가 높았어요. 같은 상황을 한 번 더 복습해 볼까요?';
    }
    if (totalVoiceAttempts > voicePassedTurns * 2) {
      return '끝까지 말해낸 점이 좋아요. 정확한 발음으로 다시 한 번 시도해 보세요!';
    }
    if (score >= 85) {
      return '안정적으로 해냈습니다. 이 흐름을 유지하며 다음 시나리오에 도전해 보세요!';
    }
    return '좋은 출발이에요. 힌트를 줄이고 마이크로 한 번 더 도전해 보세요!';
  }
}
