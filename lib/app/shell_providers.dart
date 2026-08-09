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

/// 기내사전 탭 branch index.
const kDictionaryShellTabIndex = 2;
