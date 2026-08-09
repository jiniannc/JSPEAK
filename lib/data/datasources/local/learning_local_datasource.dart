import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 로컬 학습 기록 (연습한 문장, 일별 출석).
class LearningStats {
  final Set<String> practicedSentenceIds;
  final Set<String> completionDates;

  const LearningStats({
    this.practicedSentenceIds = const {},
    this.completionDates = const {},
  });

  LearningStats copyWith({
    Set<String>? practicedSentenceIds,
    Set<String>? completionDates,
  }) {
    return LearningStats(
      practicedSentenceIds:
          practicedSentenceIds ?? this.practicedSentenceIds,
      completionDates: completionDates ?? this.completionDates,
    );
  }

  Map<String, dynamic> toJson() => {
        'practicedSentenceIds': practicedSentenceIds.toList(),
        'completionDates': completionDates.toList(),
      };

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    return LearningStats(
      practicedSentenceIds: (json['practicedSentenceIds'] as List? ?? const [])
          .map((e) => e.toString())
          .toSet(),
      completionDates: (json['completionDates'] as List? ?? const [])
          .map((e) => e.toString())
          .toSet(),
    );
  }
}

/// Hive 기반 학습 진도·스트릭 저장.
class LearningLocalDataSource {
  static const _boxName = 'jspeak_learning';
  static const _statsKey = 'learning_stats';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<LearningStats> load() async {
    final box = await _openBox();
    final raw = box.get(_statsKey);
    if (raw == null) return const LearningStats();
    try {
      return LearningStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const LearningStats();
    }
  }

  Future<void> save(LearningStats stats) async {
    final box = await _openBox();
    await box.put(_statsKey, jsonEncode(stats.toJson()));
  }
}

/// yyyy-MM-dd
String learningDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 이번 주 월(0)~일(6) 완료 여부.
List<bool> weeklyStreakFor(DateTime anchor, Set<String> completionDates) {
  final monday = DateTime(anchor.year, anchor.month, anchor.day)
      .subtract(Duration(days: anchor.weekday - DateTime.monday));
  return List.generate(7, (i) {
    final day = monday.add(Duration(days: i));
    return completionDates.contains(learningDateKey(day));
  });
}

/// 오늘 포함 연속 출석 일수.
int consecutiveStreakFor(DateTime anchor, Set<String> completionDates) {
  var streak = 0;
  var day = DateTime(anchor.year, anchor.month, anchor.day);
  while (completionDates.contains(learningDateKey(day))) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

/// 이번 달 출석(체크인) 일수.
int monthlyCheckInsFor(DateTime anchor, Set<String> completionDates) {
  final monthPrefix =
      '${anchor.year.toString().padLeft(4, '0')}-${anchor.month.toString().padLeft(2, '0')}-';
  return completionDates.where((d) => d.startsWith(monthPrefix)).length;
}
