import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/last_learning_session_local_datasource.dart';
import '../data/repositories/last_learning_session_repository.dart';

final lastLearningSessionLocalDataSourceProvider =
    Provider<LastLearningSessionLocalDataSource>(
  (ref) => LastLearningSessionLocalDataSource(),
);

final lastLearningSessionRepositoryProvider =
    Provider<LastLearningSessionRepository>((ref) {
  return LastLearningSessionRepository(
    local: ref.watch(lastLearningSessionLocalDataSourceProvider),
  );
});

class LastLearningSessionController extends Notifier<LastLearningSession?> {
  LastLearningSessionRepository get _repo =>
      ref.read(lastLearningSessionRepositoryProvider);

  @override
  LastLearningSession? build() {
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    final session = await _repo.load();
    if (!ref.mounted) return;
    state = session;
  }

  Future<void> record(LastLearningSession session) async {
    final saved = await _repo.save(session);
    if (!ref.mounted) return;
    state = saved;
  }

  Future<void> clear() async {
    await _repo.clear();
    if (!ref.mounted) return;
    state = null;
  }
}

final lastLearningSessionProvider =
    NotifierProvider<LastLearningSessionController, LastLearningSession?>(
  LastLearningSessionController.new,
);

void recordWordSwipeSession(
  WidgetRef ref, {
  required String language,
  required String category,
  required bool reviewOnly,
  required int cardIndex,
  List<String> unknownWordIds = const [],
}) {
  ref.read(lastLearningSessionProvider.notifier).record(
        LastLearningSession(
          mode: LastLearningMode.wordSwipe,
          language: language,
          lastActiveAt: DateTime.now(),
          category: category,
          reviewOnly: reviewOnly,
          cardIndex: cardIndex,
          unknownWordIds: unknownWordIds,
        ),
      );
}

void recordBasicSentenceSession(
  WidgetRef ref, {
  required String language,
  required String category,
  required String sentenceId,
}) {
  ref.read(lastLearningSessionProvider.notifier).record(
        LastLearningSession(
          mode: LastLearningMode.basicSentence,
          language: language,
          lastActiveAt: DateTime.now(),
          category: category,
          sentenceId: sentenceId,
        ),
      );
}

void recordScenarioSession(
  WidgetRef ref, {
  required String language,
  required String scenarioId,
  required int lineIndex,
}) {
  ref.read(lastLearningSessionProvider.notifier).record(
        LastLearningSession(
          mode: LastLearningMode.scenario,
          language: language,
          lastActiveAt: DateTime.now(),
          scenarioId: scenarioId,
          scenarioLineIndex: lineIndex,
        ),
      );
}
