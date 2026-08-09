import 'package:flutter/material.dart';

import '../../shared/widgets/coachmark_spotlight_tour.dart';

/// 단어 스와이프 코치마크 타겟 키.
class WordSwipeTourTargetKeys {
  final GlobalKey cardKey = GlobalKey();
  final GlobalKey unknownButtonKey = GlobalKey();
  final GlobalKey knowButtonKey = GlobalKey();
  final GlobalKey bookmarkKey = GlobalKey();
}

/// 단어 스와이프 온보딩 코치마크 투어.
class WordSwipeTour {
  static bool get isShowing => CoachmarkSpotlightTour.isShowing;

  static void dismiss() => CoachmarkSpotlightTour.dismiss();

  static List<CoachmarkTourStep> _buildSteps(WordSwipeTourTargetKeys keys) {
    return [
      CoachmarkTourStep(
        targetKey: keys.cardKey,
        title: '🃏 뜻 확인하기',
        body: '카드를 터치하면 한국어 뜻과 설명을 확인할 수 있습니다.',
        emphasisWords: const ['터치', '한국어 뜻'],
        borderRadius: 24,
        padding: const EdgeInsets.all(8),
      ),
      CoachmarkTourStep(
        targetKey: keys.unknownButtonKey,
        title: '👈 복습 필요',
        body: '헷갈리는 단어는 카드를 왼쪽으로 스와이프하거나 ❌ 버튼을 누르세요.',
        emphasisWords: const ['왼쪽으로 스와이프', '❌'],
        shape: CoachmarkTourFocusShape.circle,
        padding: const EdgeInsets.all(4),
      ),
      CoachmarkTourStep(
        targetKey: keys.knowButtonKey,
        title: '👉 암기 완료',
        body: '완전히 외운 단어는 카드를 오른쪽으로 스와이프하거나 💚 버튼을 누르세요.',
        emphasisWords: const ['오른쪽으로 스와이프', '💚'],
        shape: CoachmarkTourFocusShape.circle,
        padding: const EdgeInsets.all(4),
      ),
      CoachmarkTourStep(
        targetKey: keys.bookmarkKey,
        title: '⭐ 단어 보관함',
        body: '중요한 단어는 별표를 눌러 즐겨찾기에 추가해 보세요.',
        emphasisWords: const ['별표', '즐겨찾기'],
        shape: CoachmarkTourFocusShape.circle,
        padding: const EdgeInsets.all(4),
      ),
    ];
  }

  static Future<void> show({
    required BuildContext context,
    required WordSwipeTourTargetKeys keys,
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
