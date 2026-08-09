import '../datasources/local/learning_local_datasource.dart';
import '../models/content_bundle.dart';
import '../models/sentence.dart';

class LearningRepository {
  final LearningLocalDataSource _local;

  LearningRepository({required LearningLocalDataSource local}) : _local = local;

  Future<LearningStats> loadStats() => _local.load();

  /// 발음 연습 완료 시 호출. 문장 ID와 오늘 출석을 기록한다.
  Future<LearningStats> recordPractice(String sentenceId, {DateTime? at}) async {
    final stats = await _local.load();
    final today = learningDateKey(at ?? DateTime.now());
    final updated = stats.copyWith(
      practicedSentenceIds: {...stats.practicedSentenceIds, sentenceId},
      completionDates: {...stats.completionDates, today},
    );
    await _local.save(updated);
    return updated;
  }

  /// 홈 크루 체크인 — 오늘 출석 도장만 기록한다.
  Future<LearningStats> recordCheckIn({DateTime? at}) async {
    final stats = await _local.load();
    final today = learningDateKey(at ?? DateTime.now());
    if (stats.completionDates.contains(today)) return stats;
    final updated = stats.copyWith(
      completionDates: {...stats.completionDates, today},
    );
    await _local.save(updated);
    return updated;
  }

  /// 전체 문장 대비 연습 완료 비율 (0.0 ~ 1.0).
  double progressRatio(LearningStats stats, ContentBundle bundle) {
    if (bundle.sentences.isEmpty) return 0;
    final validIds = bundle.sentences.map((s) => s.id).toSet();
    final practiced =
        stats.practicedSentenceIds.where(validIds.contains).length;
    return (practiced / bundle.sentences.length).clamp(0.0, 1.0);
  }

  /// 날짜 기준 안정적인 오늘의 추천 문장 (필수 문장 우선, 같은 달 중복 없음).
  Sentence? pickDailySentence(ContentBundle bundle, DateTime day) {
    if (bundle.isEmpty) return null;

    final important = bundle.sentences.where((s) => s.important).toList();
    final primary = important.isNotEmpty ? important : bundle.sentences;

    return _pickUniqueForDayInMonth(
      fullPool: bundle.sentences,
      primary: primary,
      seedKey: '_all_',
      day: day,
    );
  }

  static const dailyPickPoolSize = 3;

  /// 언어별 오늘의 추천 후보 — [day]부터 같은 달 안에서 중복 없이 최대 [count]개.
  List<Sentence> pickDailySentenceCandidatesForLanguage(
    ContentBundle bundle,
    String language,
    DateTime day, {
    int count = dailyPickPoolSize,
  }) {
    if (bundle.isEmpty || count <= 0) return const [];

    final langPool =
        bundle.sentences.where((s) => s.language == language).toList();
    if (langPool.isEmpty) return const [];

    final important = langPool.where((s) => s.important).toList();
    final primary = important.isNotEmpty ? important : langPool;

    final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
    final usedIds = <String>{};
    final candidates = <Sentence>[];

    for (var d = 1; d < day.day; d++) {
      final prior = _pickOneDay(
        fullPool: langPool,
        primary: primary,
        seedKey: language,
        year: day.year,
        month: day.month,
        dayOfMonth: d,
        usedIds: usedIds,
      );
      if (prior != null) usedIds.add(prior.id);
    }

    for (var offset = 0;
        offset < count && day.day + offset <= daysInMonth;
        offset++) {
      final picked = _pickOneDay(
        fullPool: langPool,
        primary: primary,
        seedKey: language,
        year: day.year,
        month: day.month,
        dayOfMonth: day.day + offset,
        usedIds: usedIds,
      );
      if (picked == null || usedIds.contains(picked.id)) break;
      candidates.add(picked);
      usedIds.add(picked.id);
    }

    return candidates;
  }

  /// 홈 언어 스위처 연동 — 해당 언어의 오늘 추천 1문장 (같은 달 중복 없음).
  Sentence? pickDailySentenceForLanguage(
    ContentBundle bundle,
    String language,
    DateTime day,
  ) {
    final langPool =
        bundle.sentences.where((s) => s.language == language).toList();
    if (langPool.isEmpty) return null;

    final important = langPool.where((s) => s.important).toList();
    final primary = important.isNotEmpty ? important : langPool;

    return _pickUniqueForDayInMonth(
      fullPool: langPool,
      primary: primary,
      seedKey: language,
      day: day,
    );
  }

  Sentence? _pickUniqueForDayInMonth({
    required List<Sentence> fullPool,
    required List<Sentence> primary,
    required String seedKey,
    required DateTime day,
  }) {
    final usedIds = <String>{};
    Sentence? result;

    for (var d = 1; d <= day.day; d++) {
      result = _pickOneDay(
        fullPool: fullPool,
        primary: primary,
        seedKey: seedKey,
        year: day.year,
        month: day.month,
        dayOfMonth: d,
        usedIds: usedIds,
      );
      if (result != null) usedIds.add(result.id);
    }

    return result;
  }

  Sentence? _pickOneDay({
    required List<Sentence> fullPool,
    required List<Sentence> primary,
    required String seedKey,
    required int year,
    required int month,
    required int dayOfMonth,
    required Set<String> usedIds,
  }) {
    if (primary.isEmpty) return null;

    final unusedPrimary = _monthlyShuffled(primary, seedKey, year, month, 0)
        .where((s) => !usedIds.contains(s.id))
        .toList();
    if (unusedPrimary.isNotEmpty) return unusedPrimary.first;

    if (primary.length < fullPool.length) {
      final unusedLang = _monthlyShuffled(
        fullPool.where((s) => !usedIds.contains(s.id)).toList(),
        seedKey,
        year,
        month,
        1,
      );
      if (unusedLang.isNotEmpty) return unusedLang.first;
    }

    // 이번 달 가능한 문장을 모두 소진한 경우에만 반복 허용.
    final fallback = _monthlyShuffled(primary, seedKey, year, month, 0);
    return fallback[(dayOfMonth - 1) % fallback.length];
  }

  List<Sentence> _monthlyShuffled(
    List<Sentence> pool,
    String seedKey,
    int year,
    int month,
    int round,
  ) {
    if (pool.isEmpty) return const [];
    final seed = Object.hash(seedKey, year, month, round);
    return List<Sentence>.from(pool)
      ..sort(
        (a, b) =>
            _dailyPickScore(a.id, seed).compareTo(_dailyPickScore(b.id, seed)),
      );
  }

  static int _dailyPickScore(String id, int seed) => (id.hashCode ^ seed).abs();
}
