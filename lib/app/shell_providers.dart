import 'package:flutter_riverpod/flutter_riverpod.dart';

/// StatefulShell 하단 탭 인덱스 (0: 홈, 1: 학습, 2: 기내사전, 3: 마이).
final shellTabIndexProvider =
    NotifierProvider<ShellTabIndexNotifier, int>(ShellTabIndexNotifier.new);

class ShellTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (state != index) state = index;
  }
}

/// 홈 탭 진입(재선택 포함)마다 증가 — 홈 카드 등장 애니메이션 재생 토큰.
final homeEntranceEpochProvider =
    NotifierProvider<HomeEntranceEpochNotifier, int>(
      HomeEntranceEpochNotifier.new,
    );

class HomeEntranceEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// 기내사전 탭 branch index.
const kDictionaryShellTabIndex = 2;

/// 학습 탭 branch index.
const kLearningShellTabIndex = 1;

/// 챕터 도크 프로그레스 재동기화 신호.
///
/// - [fullReveal] false: 학습 화면 복귀 — 기존 진척도에서 delta만 애니메이션.
/// - [fullReveal] true: 학습 탭 재진입 — 0부터 현재 진척도까지 채움.
class HubDockResyncSignal {
  final int epoch;
  final bool fullReveal;

  const HubDockResyncSignal({
    required this.epoch,
    this.fullReveal = false,
  });

  HubDockResyncSignal next({required bool fullReveal}) =>
      HubDockResyncSignal(epoch: epoch + 1, fullReveal: fullReveal);
}

final hubDockResyncProvider =
    NotifierProvider<HubDockResyncNotifier, HubDockResyncSignal>(
  HubDockResyncNotifier.new,
);

class HubDockResyncNotifier extends Notifier<HubDockResyncSignal> {
  @override
  HubDockResyncSignal build() => const HubDockResyncSignal(epoch: 0);

  void bumpDelta() => state = state.next(fullReveal: false);

  void bumpFullReveal() => state = state.next(fullReveal: true);
}
