import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/guide_dismiss_local_datasource.dart';

final guideDismissLocalDataSourceProvider =
    Provider<GuideDismissLocalDataSource>(
  (ref) => GuideDismissLocalDataSource(),
);

class GuideDismissState {
  final bool scenario;
  final bool wordSwipe;
  final bool basicSentence;
  final bool loading;

  const GuideDismissState({
    this.scenario = false,
    this.wordSwipe = false,
    this.basicSentence = false,
    this.loading = true,
  });

  GuideDismissState copyWith({
    bool? scenario,
    bool? wordSwipe,
    bool? basicSentence,
    bool? loading,
  }) {
    return GuideDismissState(
      scenario: scenario ?? this.scenario,
      wordSwipe: wordSwipe ?? this.wordSwipe,
      basicSentence: basicSentence ?? this.basicSentence,
      loading: loading ?? this.loading,
    );
  }
}

class GuideDismissController extends Notifier<GuideDismissState> {
  GuideDismissLocalDataSource get _local =>
      ref.read(guideDismissLocalDataSourceProvider);

  @override
  GuideDismissState build() {
    _load();
    return const GuideDismissState();
  }

  Future<void> _load() async {
    final map = await _local.loadAll();
    state = GuideDismissState(
      scenario: map[GuideDismissLocalDataSource.keyScenario] == true,
      wordSwipe: map[GuideDismissLocalDataSource.keyWordSwipe] == true,
      basicSentence:
          map[GuideDismissLocalDataSource.keyBasicSentence] == true,
      loading: false,
    );
  }

  Future<void> dismissScenario() async {
    await _local.dismiss(GuideDismissLocalDataSource.keyScenario);
    state = state.copyWith(scenario: true, loading: false);
  }

  Future<void> dismissWordSwipe() async {
    await _local.dismiss(GuideDismissLocalDataSource.keyWordSwipe);
    state = state.copyWith(wordSwipe: true, loading: false);
  }

  Future<void> dismissBasicSentence() async {
    await _local.dismiss(GuideDismissLocalDataSource.keyBasicSentence);
    state = state.copyWith(basicSentence: true, loading: false);
  }

  Future<void> restoreScenario() async {
    await _local.restore(GuideDismissLocalDataSource.keyScenario);
    state = state.copyWith(scenario: false, loading: false);
  }

  Future<void> restoreWordSwipe() async {
    await _local.restore(GuideDismissLocalDataSource.keyWordSwipe);
    state = state.copyWith(wordSwipe: false, loading: false);
  }

  Future<void> restoreBasicSentence() async {
    await _local.restore(GuideDismissLocalDataSource.keyBasicSentence);
    state = state.copyWith(basicSentence: false, loading: false);
  }
}

final guideDismissProvider =
    NotifierProvider<GuideDismissController, GuideDismissState>(
  GuideDismissController.new,
);
