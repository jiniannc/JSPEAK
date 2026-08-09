import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 문장 단위 3단계 학습 상태.
class SentenceStageProgress {
  final bool isRead;
  final bool isAttempted;
  final bool isMastered;

  /// 오디오 재생(듣기) 버튼을 눌렀을 때만 true — `isRead`와 분리.
  final bool hasListened;

  const SentenceStageProgress({
    this.isRead = false,
    this.isAttempted = false,
    this.isMastered = false,
    this.hasListened = false,
  });

  SentenceStageProgress copyWith({
    bool? isRead,
    bool? isAttempted,
    bool? isMastered,
    bool? hasListened,
  }) {
    return SentenceStageProgress(
      isRead: isRead ?? this.isRead,
      isAttempted: isAttempted ?? this.isAttempted,
      isMastered: isMastered ?? this.isMastered,
      hasListened: hasListened ?? this.hasListened,
    );
  }

  Map<String, dynamic> toJson() => {
        'isRead': isRead,
        'isAttempted': isAttempted,
        'isMastered': isMastered,
        'hasListened': hasListened,
      };

  factory SentenceStageProgress.fromJson(Map<String, dynamic> json) {
    return SentenceStageProgress(
      isRead: json['isRead'] == true,
      isAttempted: json['isAttempted'] == true,
      isMastered: json['isMastered'] == true,
      hasListened: json['hasListened'] == true,
    );
  }
}

/// 언어·카테고리·문장별 기본 문장 학습 진도.
class SentenceProgressStats {
  /// key: sentenceId
  final Map<String, SentenceStageProgress> bySentenceId;

  const SentenceProgressStats({this.bySentenceId = const {}});

  SentenceStageProgress forSentence(String sentenceId) =>
      bySentenceId[sentenceId] ?? const SentenceStageProgress();

  SentenceProgressStats copyWith({
    Map<String, SentenceStageProgress>? bySentenceId,
  }) {
    return SentenceProgressStats(
      bySentenceId: bySentenceId ?? this.bySentenceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'bySentenceId': bySentenceId.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory SentenceProgressStats.fromJson(Map<String, dynamic> json) {
    final raw = json['bySentenceId'] as Map<String, dynamic>? ?? {};
    return SentenceProgressStats(
      bySentenceId: raw.map(
        (k, v) => MapEntry(
          k,
          SentenceStageProgress.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
    );
  }
}

class SentenceProgressLocalDataSource {
  static const _boxName = 'jspeak_sentence_progress';
  static const _statsKey = 'sentence_progress_stats';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<SentenceProgressStats> load() async {
    final box = await _openBox();
    final raw = box.get(_statsKey);
    if (raw == null) return const SentenceProgressStats();
    try {
      return SentenceProgressStats.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const SentenceProgressStats();
    }
  }

  Future<void> save(SentenceProgressStats stats) async {
    final box = await _openBox();
    await box.put(_statsKey, jsonEncode(stats.toJson()));
  }
}
