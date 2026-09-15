import '../datasources/local/last_learning_session_local_datasource.dart';

class LastLearningSessionRepository {
  final LastLearningSessionLocalDataSource _local;

  LastLearningSessionRepository({required LastLearningSessionLocalDataSource local})
      : _local = local;

  Future<LastLearningSession?> load() => _local.load();

  Future<LastLearningSession> save(LastLearningSession session) async {
    final next = session.copyWith(lastActiveAt: DateTime.now());
    await _local.save(next);
    return next;
  }

  Future<void> clear() => _local.clear();
}
