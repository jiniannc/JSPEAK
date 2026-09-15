import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

enum LastLearningMode { wordSwipe, basicSentence, scenario }

/// 마지막으로 진입한 학습 모드와 위치.
class LastLearningSession {
  final LastLearningMode mode;
  final String language;
  final DateTime lastActiveAt;
  final String? category;
  final bool reviewOnly;
  final int? cardIndex;
  final List<String> unknownWordIds;
  final String? sentenceId;
  final String? scenarioId;
  final int? scenarioLineIndex;

  const LastLearningSession({
    required this.mode,
    required this.language,
    required this.lastActiveAt,
    this.category,
    this.reviewOnly = false,
    this.cardIndex,
    this.unknownWordIds = const [],
    this.sentenceId,
    this.scenarioId,
    this.scenarioLineIndex,
  });

  LastLearningSession copyWith({
    LastLearningMode? mode,
    String? language,
    DateTime? lastActiveAt,
    String? category,
    bool? reviewOnly,
    int? cardIndex,
    List<String>? unknownWordIds,
    String? sentenceId,
    String? scenarioId,
    int? scenarioLineIndex,
  }) {
    return LastLearningSession(
      mode: mode ?? this.mode,
      language: language ?? this.language,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      category: category ?? this.category,
      reviewOnly: reviewOnly ?? this.reviewOnly,
      cardIndex: cardIndex ?? this.cardIndex,
      unknownWordIds: unknownWordIds ?? this.unknownWordIds,
      sentenceId: sentenceId ?? this.sentenceId,
      scenarioId: scenarioId ?? this.scenarioId,
      scenarioLineIndex: scenarioLineIndex ?? this.scenarioLineIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'language': language,
        'lastActiveAt': lastActiveAt.toIso8601String(),
        if (category != null) 'category': category,
        'reviewOnly': reviewOnly,
        if (cardIndex != null) 'cardIndex': cardIndex,
        'unknownWordIds': unknownWordIds,
        if (sentenceId != null) 'sentenceId': sentenceId,
        if (scenarioId != null) 'scenarioId': scenarioId,
        if (scenarioLineIndex != null) 'scenarioLineIndex': scenarioLineIndex,
      };

  factory LastLearningSession.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String? ?? LastLearningMode.basicSentence.name;
    final mode = LastLearningMode.values.firstWhere(
      (value) => value.name == modeName,
      orElse: () => LastLearningMode.basicSentence,
    );
    final rawAt = json['lastActiveAt'] as String?;
    return LastLearningSession(
      mode: mode,
      language: json['language'] as String? ?? 'English',
      lastActiveAt: rawAt == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.tryParse(rawAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      category: json['category'] as String?,
      reviewOnly: json['reviewOnly'] == true,
      cardIndex: (json['cardIndex'] as num?)?.round(),
      unknownWordIds: (json['unknownWordIds'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      sentenceId: json['sentenceId'] as String?,
      scenarioId: json['scenarioId'] as String?,
      scenarioLineIndex: (json['scenarioLineIndex'] as num?)?.round(),
    );
  }
}

class LastLearningSessionLocalDataSource {
  static const _boxName = 'jspeak_last_learning_session';
  static const _sessionKey = 'last_learning_session';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<LastLearningSession?> load() async {
    final box = await _openBox();
    final raw = box.get(_sessionKey);
    if (raw == null) return null;
    try {
      return LastLearningSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LastLearningSession session) async {
    final box = await _openBox();
    await box.put(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final box = await _openBox();
    await box.delete(_sessionKey);
  }
}
