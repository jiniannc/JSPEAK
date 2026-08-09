import '../models/content_bundle.dart';
import '../models/scenario.dart';
import '../datasources/local/scenario_progress_local_datasource.dart';

/// 언어별 시나리오 학습 진도 비즈니스 로직.
class ScenarioProgressRepository {
  final ScenarioProgressLocalDataSource _local;

  ScenarioProgressRepository({required ScenarioProgressLocalDataSource local})
      : _local = local;

  Future<ScenarioProgressStats> loadStats() => _local.load();

  /// 특정 시나리오를 완료 처리한다.
  Future<void> markCompleted({
    required String language,
    required String scenarioId,
  }) async {
    final stats = await _local.load();
    final updated = Map<String, Set<String>>.from(stats.completedByLanguage);
    final ids = Set<String>.from(updated[language] ?? {});
    ids.add(scenarioId);
    updated[language] = ids;
    await _local.save(stats.copyWith(completedByLanguage: updated));
  }

  /// 언어별 진도율 (0.0 ~ 100.0).
  double progressPercent({
    required String language,
    required List<Scenario> scenarios,
    required ScenarioProgressStats stats,
  }) {
    final total = scenarios.where((s) => s.language == language).length;
    if (total == 0) return 0;
    final completed = stats.completedFor(language)
        .where((id) => scenarios.any((s) => s.id == id))
        .length;
    return (completed / total * 100).clamp(0.0, 100.0);
  }

  /// 언어별 진도 비율 (0.0 ~ 1.0).
  double progressRatio({
    required String language,
    required List<Scenario> scenarios,
    required ScenarioProgressStats stats,
  }) =>
      progressPercent(
            language: language,
            scenarios: scenarios,
            stats: stats,
          ) /
      100;

  /// 전체 언어 평균 진도율 (0.0 ~ 100.0).
  double overallProgressPercent({
    required ContentBundle bundle,
    required ScenarioProgressStats stats,
    List<String> languages = const ['English', 'Japanese', 'Chinese'],
  }) {
    final scenarios = bundle.scenarios;
    if (scenarios.isEmpty) return 0;

    var sum = 0.0;
    var count = 0;
    for (final lang in languages) {
      final total = scenarios.where((s) => s.language == lang).length;
      if (total == 0) continue;
      sum += progressPercent(
        language: lang,
        scenarios: scenarios,
        stats: stats,
      );
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  int completedCount({
    required String language,
    required List<Scenario> scenarios,
    required ScenarioProgressStats stats,
  }) =>
      stats.completedFor(language)
          .where((id) => scenarios.any((s) => s.id == id))
          .length;

  int totalCount({
    required String language,
    required List<Scenario> scenarios,
  }) =>
      scenarios.where((s) => s.language == language).length;
}
