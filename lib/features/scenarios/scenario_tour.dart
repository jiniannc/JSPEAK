import 'package:flutter/material.dart';

import '../../shared/widgets/coachmark_spotlight_tour.dart';

/// 시나리오 롤플레이 코치마크 타겟 키.
class ScenarioTourTargetKeys {
  final GlobalKey opponentBubbleKey = GlobalKey();
  final GlobalKey micKey = GlobalKey();
  final GlobalKey toolbarKey = GlobalKey();
}

/// 시나리오 온보딩 코치마크 투어.
class ScenarioTour {
  static bool get isShowing => CoachmarkSpotlightTour.isShowing;

  static void dismiss() => CoachmarkSpotlightTour.dismiss();

  static List<CoachmarkTourStep> _buildSteps(ScenarioTourTargetKeys keys) {
    return [
      CoachmarkTourStep(
        targetKey: keys.opponentBubbleKey,
        title: '💬 대화 내용 확인',
        body: '제시되는 대화를 읽고 상황을 파악하세요.',
        emphasisWords: const ['제시되는', '대화', '상황'],
        borderRadius: 24,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        preferTooltipBelow: true,
      ),
      CoachmarkTourStep(
        targetKey: keys.micKey,
        title: '🎙️ AI 음성 답변',
        body: '마이크 버튼을 누르고 알맞은 문장을 직접 말하거나 키보드로 입력해 보세요.',
        emphasisWords: const ['마이크 버튼', '직접 말', '키보드로 입력'],
        shape: CoachmarkTourFocusShape.circle,
        padding: const EdgeInsets.all(6),
      ),
      CoachmarkTourStep(
        targetKey: keys.toolbarKey,
        title: '💡 답변 지원 도구',
        body: '문장이 떠오르지 않을 땐 힌트를 보거나 정답을 확인해 보세요.',
        emphasisWords: const ['힌트', '정답'],
        borderRadius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    ];
  }

  static Future<void> show({
    required BuildContext context,
    required ScenarioTourTargetKeys keys,
    required VoidCallback onComplete,
    required VoidCallback onSkip,
  }) async {
    await CoachmarkSpotlightTour.show(
      context: context,
      steps: _buildSteps(keys),
      onComplete: onComplete,
      onSkip: onSkip,
    );
  }
}
