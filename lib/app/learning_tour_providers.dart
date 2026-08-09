import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/learning_tour_local_datasource.dart';

final learningTourLocalDataSourceProvider =
    Provider<LearningTourLocalDataSource>(
  (ref) => LearningTourLocalDataSource(),
);

/// `가이드 다시보기` 등 외부에서 투어 재실행을 요청할 때 증가시킨다.
final learningTourReplaySignalProvider =
    NotifierProvider<LearningTourReplaySignal, int>(
  LearningTourReplaySignal.new,
);

class LearningTourReplaySignal extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final wordSwipeTourReplaySignalProvider =
    NotifierProvider<WordSwipeTourReplaySignal, int>(
  WordSwipeTourReplaySignal.new,
);

class WordSwipeTourReplaySignal extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final scenarioTourReplaySignalProvider =
    NotifierProvider<ScenarioTourReplaySignal, int>(
  ScenarioTourReplaySignal.new,
);

class ScenarioTourReplaySignal extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
