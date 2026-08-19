import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 한 카테고리(챕터)의 스와이프 학습 결과.
class SwipeCategoryProgress {
  final bool played;
  final int totalCount;
  final Set<String> unknownWordIds;
  final Set<String> knownWordIds;
  final DateTime? lastStudiedAt;

  const SwipeCategoryProgress({
    this.played = false,
    this.totalCount = 0,
    this.unknownWordIds = const {},
    this.knownWordIds = const {},
    this.lastStudiedAt,
  });

  int get unknownCount => unknownWordIds.length;

  int get knownCount {
    if (!played) return 0;
    // 모르는 단어가 없으면 카테고리 전체를 완료로 본다.
    // (중복 ID 때문에 knownWordIds.length < totalCount 가 되는 경우 보정)
    if (unknownCount == 0) {
      if (totalCount > 0) return totalCount;
      return knownWordIds.length;
    }
    if (knownWordIds.isNotEmpty) {
      final counted = knownWordIds.length;
      return totalCount > 0 ? counted.clamp(0, totalCount) : counted;
    }
    return (totalCount - unknownCount).clamp(0, totalCount);
  }

  bool get isMastered =>
      played && totalCount > 0 && unknownCount == 0;

  /// 0.0 ~ 1.0 — 미시행이면 0.
  double get completionRatio {
    if (!played || totalCount <= 0) return 0;
    return (knownCount / totalCount).clamp(0.0, 1.0);
  }

  SwipeCategoryProgress copyWith({
    bool? played,
    int? totalCount,
    Set<String>? unknownWordIds,
    Set<String>? knownWordIds,
    DateTime? lastStudiedAt,
    bool clearLastStudiedAt = false,
  }) {
    return SwipeCategoryProgress(
      played: played ?? this.played,
      totalCount: totalCount ?? this.totalCount,
      unknownWordIds: unknownWordIds ?? this.unknownWordIds,
      knownWordIds: knownWordIds ?? this.knownWordIds,
      lastStudiedAt: clearLastStudiedAt
          ? null
          : (lastStudiedAt ?? this.lastStudiedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'played': played,
        'totalCount': totalCount,
        'unknownWordIds': unknownWordIds.toList(),
        'knownWordIds': knownWordIds.toList(),
        if (lastStudiedAt != null)
          'lastStudiedAt': lastStudiedAt!.toIso8601String(),
      };

  factory SwipeCategoryProgress.fromJson(Map<String, dynamic> json) {
    DateTime? studiedAt;
    final rawAt = json['lastStudiedAt'];
    if (rawAt is String && rawAt.isNotEmpty) {
      studiedAt = DateTime.tryParse(rawAt);
    }
    return SwipeCategoryProgress(
      played: json['played'] == true,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      unknownWordIds: {
        for (final e in (json['unknownWordIds'] as List? ?? const []))
          e.toString(),
      },
      knownWordIds: {
        for (final e in (json['knownWordIds'] as List? ?? const []))
          e.toString(),
      },
      lastStudiedAt: studiedAt,
    );
  }
}

/// 언어·카테고리별 스와이프 진도.
class SwipeProgressStats {
  /// key: `$language|$category`
  final Map<String, SwipeCategoryProgress> byKey;

  const SwipeProgressStats({this.byKey = const {}});

  static String keyFor(String language, String category) =>
      '$language|$category';

  SwipeCategoryProgress forCategory(String language, String category) =>
      byKey[keyFor(language, category)] ?? const SwipeCategoryProgress();

  SwipeProgressStats copyWith({
    Map<String, SwipeCategoryProgress>? byKey,
  }) {
    return SwipeProgressStats(byKey: byKey ?? this.byKey);
  }

  Map<String, dynamic> toJson() => {
        'byKey': byKey.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory SwipeProgressStats.fromJson(Map<String, dynamic> json) {
    final raw = json['byKey'] as Map<String, dynamic>? ?? {};
    return SwipeProgressStats(
      byKey: raw.map(
        (k, v) => MapEntry(
          k,
          SwipeCategoryProgress.fromJson(
            Map<String, dynamic>.from(v as Map),
          ),
        ),
      ),
    );
  }
}

/// Hive 기반 스와이프 학습 진도 저장.
class SwipeProgressLocalDataSource {
  static const _boxName = 'jspeak_swipe_progress';
  static const _statsKey = 'swipe_progress_stats';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<SwipeProgressStats> load() async {
    final box = await _openBox();
    final raw = box.get(_statsKey);
    if (raw == null) return const SwipeProgressStats();
    try {
      return SwipeProgressStats.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const SwipeProgressStats();
    }
  }

  Future<void> save(SwipeProgressStats stats) async {
    final box = await _openBox();
    await box.put(_statsKey, jsonEncode(stats.toJson()));
  }
}
