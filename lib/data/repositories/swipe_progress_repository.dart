import '../datasources/local/swipe_progress_local_datasource.dart';
import '../models/content_bundle.dart';
import '../models/word_model.dart';

/// 스와이프 단어 학습 진도 비즈니스 로직.
class SwipeProgressRepository {
  final SwipeProgressLocalDataSource _local;

  SwipeProgressRepository({required SwipeProgressLocalDataSource local})
      : _local = local;

  Future<SwipeProgressStats> loadStats() => _local.load();

  /// 세션 종료 시 카테고리 진도 저장.
  Future<SwipeProgressStats> saveCategoryResult({
    required String language,
    required String category,
    required List<String> allWordIds,
    required List<String> unknownWordIds,
  }) async {
    final stats = await _local.load();
    final unknown = unknownWordIds.toSet();
    final known = {
      for (final id in allWordIds)
        if (!unknown.contains(id)) id,
    };
    final now = DateTime.now();
    final progress = SwipeCategoryProgress(
      played: true,
      totalCount: allWordIds.length,
      unknownWordIds: unknown,
      knownWordIds: known,
      lastStudiedAt: now,
    );
    final updated = Map<String, SwipeCategoryProgress>.from(stats.byKey);
    updated[SwipeProgressStats.keyFor(language, category)] = progress;
    final next = stats.copyWith(byKey: updated);
    await _local.save(next);
    return next;
  }

  /// 리뷰 세션만 반영 — 리뷰한 단어들의 앎/모름만 갱신.
  Future<SwipeProgressStats> updateReviewResult({
    required String language,
    required String category,
    required List<String> reviewedWordIds,
    required List<String> stillUnknownWordIds,
  }) async {
    final stats = await _local.load();
    final current = stats.forCategory(language, category);
    if (!current.played) {
      return saveCategoryResult(
        language: language,
        category: category,
        allWordIds: reviewedWordIds,
        unknownWordIds: stillUnknownWordIds,
      );
    }

    final stillUnknown = stillUnknownWordIds.toSet();
    final reviewed = reviewedWordIds.toSet();
    final nextUnknown = Set<String>.from(current.unknownWordIds)
      ..removeAll(reviewed)
      ..addAll(stillUnknown);
    final nextKnown = Set<String>.from(current.knownWordIds)
      ..addAll(reviewed.difference(stillUnknown))
      ..removeAll(stillUnknown);

    final progress = current.copyWith(
      unknownWordIds: nextUnknown,
      knownWordIds: nextKnown,
      totalCount: current.totalCount > 0
          ? current.totalCount
          : (nextKnown.length + nextUnknown.length),
      lastStudiedAt: DateTime.now(),
    );
    final updated = Map<String, SwipeCategoryProgress>.from(stats.byKey);
    updated[SwipeProgressStats.keyFor(language, category)] = progress;
    final next = stats.copyWith(byKey: updated);
    await _local.save(next);
    return next;
  }

  /// 언어별 완료율 (0~100). 미시행 챕터는 0으로 반영.
  double languageProgressPercent({
    required String language,
    required ContentBundle bundle,
    required SwipeProgressStats stats,
  }) {
    final categories = bundle.categoriesForWords(language);
    if (categories.isEmpty) return 0;

    var knownSum = 0;
    var totalSum = 0;
    for (final cat in categories) {
      final words = bundle.wordsFor(language, cat);
      final total = words.length;
      if (total == 0) continue;
      totalSum += total;
      final progress = stats.forCategory(language, cat);
      if (!progress.played) continue;
      knownSum += progress.knownCount.clamp(0, total);
    }
    if (totalSum == 0) return 0;
    return (knownSum / totalSum * 100).clamp(0.0, 100.0);
  }

  int languageKnownCount({
    required String language,
    required ContentBundle bundle,
    required SwipeProgressStats stats,
  }) {
    var known = 0;
    for (final cat in bundle.categoriesForWords(language)) {
      final progress = stats.forCategory(language, cat);
      if (!progress.played) continue;
      known += progress.knownCount;
    }
    return known;
  }

  int languageTotalCount({
    required String language,
    required ContentBundle bundle,
  }) {
    var total = 0;
    for (final cat in bundle.categoriesForWords(language)) {
      total += bundle.wordsFor(language, cat).length;
    }
    return total;
  }

  /// 세션용 안정적 단어 ID.
  static String wordId({
    required String language,
    required String category,
    required String term,
    required String meaning,
  }) {
    final code = WordModel.languageCode(language);
    return '${code}_${category}_${term}_$meaning';
  }
}
