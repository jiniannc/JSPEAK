import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 언어별 완료된 시나리오 ID 집합 + 최근 퍼포먼스 기록.
class ScenarioProgressStats {
  final Map<String, Set<String>> completedByLanguage;
  /// 언어 → 시나리오 ID → 최근 performance 점수 (0~100).
  final Map<String, Map<String, int>> lastPerformanceByLanguage;

  const ScenarioProgressStats({
    this.completedByLanguage = const {},
    this.lastPerformanceByLanguage = const {},
  });

  Set<String> completedFor(String language) =>
      completedByLanguage[language] ?? const {};

  bool isCompleted(String language, String scenarioId) =>
      completedFor(language).contains(scenarioId);

  int? lastPerformance(String language, String scenarioId) =>
      lastPerformanceByLanguage[language]?[scenarioId];

  ScenarioProgressStats copyWith({
    Map<String, Set<String>>? completedByLanguage,
    Map<String, Map<String, int>>? lastPerformanceByLanguage,
  }) {
    return ScenarioProgressStats(
      completedByLanguage: completedByLanguage ?? this.completedByLanguage,
      lastPerformanceByLanguage:
          lastPerformanceByLanguage ?? this.lastPerformanceByLanguage,
    );
  }

  Map<String, dynamic> toJson() => {
        'completedByLanguage': completedByLanguage.map(
          (lang, ids) => MapEntry(lang, ids.toList()),
        ),
        'lastPerformanceByLanguage': lastPerformanceByLanguage.map(
          (lang, scores) => MapEntry(lang, scores),
        ),
      };

  factory ScenarioProgressStats.fromJson(Map<String, dynamic> json) {
    final raw = json['completedByLanguage'] as Map<String, dynamic>? ?? {};
    final perfRaw =
        json['lastPerformanceByLanguage'] as Map<String, dynamic>? ?? {};
    return ScenarioProgressStats(
      completedByLanguage: raw.map(
        (lang, value) => MapEntry(
          lang,
          (value as List? ?? const []).map((e) => e.toString()).toSet(),
        ),
      ),
      lastPerformanceByLanguage: perfRaw.map(
        (lang, value) => MapEntry(
          lang,
          (value as Map<String, dynamic>).map(
            (id, score) => MapEntry(id, (score as num).round()),
          ),
        ),
      ),
    );
  }
}

/// Hive 기반 시나리오 학습 진도 저장.
class ScenarioProgressLocalDataSource {
  static const _boxName = 'jspeak_scenario_progress';
  static const _statsKey = 'scenario_progress_stats';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<ScenarioProgressStats> load() async {
    final box = await _openBox();
    final raw = box.get(_statsKey);
    if (raw == null) return const ScenarioProgressStats();
    try {
      return ScenarioProgressStats.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ScenarioProgressStats();
    }
  }

  Future<void> save(ScenarioProgressStats stats) async {
    final box = await _openBox();
    await box.put(_statsKey, jsonEncode(stats.toJson()));
  }
}
