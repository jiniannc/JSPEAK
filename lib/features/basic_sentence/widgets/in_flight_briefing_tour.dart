import 'package:flutter/material.dart';

import '../../../shared/widgets/coachmark_spotlight_tour.dart';

/// 3D 휠 학습 패널 코치마크 타겟 키.
class LearningTourTargetKeys {
  final GlobalKey stampsKey = GlobalKey();
  final GlobalKey bookmarkKey = GlobalKey();
  /// 재생 슬라이더 + 배속 칩 + 재생 버튼 덱 (오디오 없으면 투어 단계 생략).
  final GlobalKey playbackDeckKey = GlobalKey();
  final GlobalKey speakKey = GlobalKey();
  final GlobalKey swipeKey = GlobalKey();
}

/// 기내 온보딩 코치마크 투어 — 글래스 툴팁 + 스팟라이트 오버레이.
class InFlightBriefingTour {
  static bool get isShowing => CoachmarkSpotlightTour.isShowing;

  static void dismiss() => CoachmarkSpotlightTour.dismiss();

  static List<CoachmarkTourStep> _buildSteps(LearningTourTargetKeys keys) {
    return [
      CoachmarkTourStep(
        targetKey: keys.stampsKey,
        title: '🏆 3단계 훈련 스탬프',
        body: '듣기, 말하기를 완료하여 카드를 마스터해보세요.',
        emphasisWords: const ['듣기', '말하기', '마스터'],
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      CoachmarkTourStep(
        targetKey: keys.bookmarkKey,
        title: '⭐ 표현 보관함',
        body: '중요한 문장은 별을 눌러 즐겨찾기에 추가해 보세요.',
        emphasisWords: const ['별', '즐겨찾기'],
        shape: CoachmarkTourFocusShape.circle,
        padding: const EdgeInsets.all(6),
      ),
      CoachmarkTourStep(
        targetKey: keys.playbackDeckKey,
        title: '🔊 듣기 & 속도 조절',
        body: '재생으로 들어보고, 0.5×·0.75× 배속으로 천천히 연습해 보세요.',
        emphasisWords: const ['0.5×·0.75×', '재생'],
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      CoachmarkTourStep(
        targetKey: keys.speakKey,
        title: '🎙️ AI 말하기 연습',
        body: '버튼을 누르고 직접 말하면 실시간 발음 채점이 진행됩니다.',
        emphasisWords: const ['실시간 발음 채점'],
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      CoachmarkTourStep(
        targetKey: keys.swipeKey,
        title: '↕️ 스와이프 이동',
        body: '카드를 위아래로 스와이프하여 다음 표현으로 넘어가세요.',
        emphasisWords: const ['위아래로 스와이프'],
        borderRadius: 26,
        padding: const EdgeInsets.all(10),
      ),
    ];
  }

  static Future<void> show({
    required BuildContext context,
    required LearningTourTargetKeys keys,
    required VoidCallback onComplete,
    required VoidCallback onSkip,
    bool includeSpeedStep = true,
  }) async {
    var steps = _buildSteps(keys);
    if (!includeSpeedStep) {
      steps = steps.where((s) => s.targetKey != keys.playbackDeckKey).toList();
    }

    await CoachmarkSpotlightTour.show(
      context: context,
      steps: steps,
      onComplete: onComplete,
      onSkip: onSkip,
    );
  }
}
