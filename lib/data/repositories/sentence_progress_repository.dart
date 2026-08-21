import '../datasources/local/sentence_progress_local_datasource.dart';
import '../models/content_bundle.dart';
import '../models/sentence.dart';

/// 챕터(주제) 단위 집계.
class SentenceCategorySummary {
  final int total;
  final int readCount;
  final int attemptedCount;
  final int masteredCount;

  const SentenceCategorySummary({
    required this.total,
    required this.readCount,
    required this.attemptedCount,
    required this.masteredCount,
  });

  bool get allRead => total > 0 && readCount >= total;
  bool get allAttempted => total > 0 && attemptedCount >= total;
  bool get allMastered => total > 0 && masteredCount >= total;

  double get attemptedRatio => total == 0 ? 0 : attemptedCount / total;
}

class SentenceProgressRepository {
  final SentenceProgressLocalDataSource _local;

  SentenceProgressRepository({required SentenceProgressLocalDataSource local})
      : _local = local;

  Future<SentenceProgressStats> loadStats() => _local.load();

  Future<SentenceProgressStats> _update(
    String sentenceId,
    SentenceStageProgress Function(SentenceStageProgress) transform,
  ) async {
    final stats = await _local.load();
    final current = stats.forSentence(sentenceId);
    final next = transform(current);
    final map = Map<String, SentenceStageProgress>.from(stats.bySentenceId);
    map[sentenceId] = next;
    final updated = stats.copyWith(bySentenceId: map);
    await _local.save(updated);
    return updated;
  }

  Future<SentenceProgressStats> markRead(String sentenceId) {
    return _update(
      sentenceId,
      (c) => c.isRead ? c : c.copyWith(isRead: true),
    );
  }

  /// 재생(듣기) 버튼 탭 전용 — 듣기 미션 뱃지만 이 값으로 판정한다.
  Future<SentenceProgressStats> markListened(String sentenceId) {
    return _update(
      sentenceId,
      (c) => c.hasListened
          ? c
          : c.copyWith(hasListened: true, isRead: true),
    );
  }

  /// 녹음 세션을 끝까지 마쳤을 때 (점수 무관).
  Future<SentenceProgressStats> markAttempted(String sentenceId) {
    return _update(
      sentenceId,
      (c) => c.copyWith(isRead: true, isAttempted: true),
    );
  }

  /// 점수 80점 이상 패스.
  Future<SentenceProgressStats> markMastered(String sentenceId) {
    return _update(
      sentenceId,
      (c) => c.copyWith(
        isRead: true,
        isAttempted: true,
        isMastered: true,
      ),
    );
  }

  /// 세션 종료 시 점수에 따라 attempted / mastered 갱신.
  Future<SentenceProgressStats> recordPracticeResult({
    required String sentenceId,
    required int accuracy,
    required bool hasSpokenText,
  }) async {
    if (!hasSpokenText) {
      return markAttempted(sentenceId);
    }
    if (accuracy >= 80) {
      return markMastered(sentenceId);
    }
    return markAttempted(sentenceId);
  }

  SentenceCategorySummary categorySummary({
    required List<Sentence> sentences,
    required SentenceProgressStats stats,
  }) {
    var read = 0;
    var attempted = 0;
    var mastered = 0;
    for (final s in sentences) {
      final p = stats.forSentence(s.id);
      if (p.isRead) read++;
      if (p.isAttempted) attempted++;
      if (p.isMastered) mastered++;
    }
    return SentenceCategorySummary(
      total: sentences.length,
      readCount: read,
      attemptedCount: attempted,
      masteredCount: mastered,
    );
  }

  /// 언어 게이지: isAttempted 기준 (0~100).
  double languageProgressPercent({
    required String language,
    required ContentBundle bundle,
    required SentenceProgressStats stats,
  }) {
    final sentences =
        bundle.sentences.where((s) => s.language == language).toList();
    if (sentences.isEmpty) return 0;
    final attempted = sentences
        .where((s) => stats.forSentence(s.id).isAttempted)
        .length;
    return (attempted / sentences.length * 100).clamp(0.0, 100.0);
  }

  int languageAttemptedCount({
    required String language,
    required ContentBundle bundle,
    required SentenceProgressStats stats,
  }) {
    return bundle.sentences
        .where((s) =>
            s.language == language && stats.forSentence(s.id).isAttempted)
        .length;
  }

  int languageTotalCount({
    required String language,
    required ContentBundle bundle,
  }) {
    return bundle.sentences.where((s) => s.language == language).length;
  }

  /// 언어 전체 문장 스탬프 진도 — 문장별 LISTEN/SPEAK/MASTER 합산 (0~100).
  double languageSentenceStampPercent({
    required String language,
    required ContentBundle bundle,
    required SentenceProgressStats stats,
  }) {
    final sentences =
        bundle.sentences.where((s) => s.language == language).toList();
    if (sentences.isEmpty) return 0;

    var earned = 0;
    for (final sentence in sentences) {
      final progress = stats.forSentence(sentence.id);
      if (progress.hasListened || progress.isRead) earned++;
      if (progress.isAttempted) earned++;
      if (progress.isMastered) earned++;
    }

    final possible = sentences.length * 3;
    if (possible == 0) return 0;
    return (earned / possible * 100).clamp(0.0, 100.0);
  }

  /// 언어 단위 스탬프 집계 — 주제(챕터)당 1개씩.
  /// read/attempted/mastered = 해당 단계를 전부 채운 주제 수, total = 주제 수.
  SentenceCategorySummary languageStampSummary({
    required String language,
    required ContentBundle bundle,
    required SentenceProgressStats stats,
  }) {
    final categories = bundle.categoriesFor(language);
    var readChapters = 0;
    var attemptedChapters = 0;
    var masteredChapters = 0;

    for (final category in categories) {
      final summary = categorySummary(
        sentences: bundle.sentencesFor(language, category),
        stats: stats,
      );
      if (summary.allRead) readChapters++;
      if (summary.allAttempted) attemptedChapters++;
      if (summary.allMastered) masteredChapters++;
    }

    return SentenceCategorySummary(
      total: categories.length,
      readCount: readChapters,
      attemptedCount: attemptedChapters,
      masteredCount: masteredChapters,
    );
  }
}
