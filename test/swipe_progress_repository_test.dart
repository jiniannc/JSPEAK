import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/data/datasources/local/swipe_progress_local_datasource.dart';
import 'package:jspeak/data/models/content_bundle.dart';
import 'package:jspeak/data/models/vocabulary_entry.dart';
import 'package:jspeak/data/repositories/swipe_progress_repository.dart';

class _MemorySwipeLocal extends SwipeProgressLocalDataSource {
  SwipeProgressStats _stats = const SwipeProgressStats();

  @override
  Future<SwipeProgressStats> load() async => _stats;

  @override
  Future<void> save(SwipeProgressStats stats) async {
    _stats = stats;
  }
}

void main() {
  test('saveCategoryResult and language gauge', () async {
    final repo = SwipeProgressRepository(local: _MemorySwipeLocal());
    final bundle = ContentBundle(
      sentences: const [],
      categoryOrder: const ['Safety', 'Service'],
      words: [
        const VocabularyEntry(
          language: 'English',
          term: 'seatbelt',
          meaning: '안전벨트',
          category: 'Safety',
        ),
        const VocabularyEntry(
          language: 'English',
          term: 'exit',
          meaning: '비상구',
          category: 'Safety',
        ),
        const VocabularyEntry(
          language: 'English',
          term: 'coffee',
          meaning: '커피',
          category: 'Service',
        ),
      ],
    );

    final ids = [
      SwipeProgressRepository.wordId(
        language: 'English',
        category: 'Safety',
        term: 'seatbelt',
        meaning: '안전벨트',
      ),
      SwipeProgressRepository.wordId(
        language: 'English',
        category: 'Safety',
        term: 'exit',
        meaning: '비상구',
      ),
    ];

    var stats = await repo.saveCategoryResult(
      language: 'English',
      category: 'Safety',
      allWordIds: ids,
      unknownWordIds: [ids.first],
    );

    final safety = stats.forCategory('English', 'Safety');
    expect(safety.played, isTrue);
    expect(safety.unknownCount, 1);
    expect(safety.knownCount, 1);
    expect(safety.isMastered, isFalse);

    final percent = repo.languageProgressPercent(
      language: 'English',
      bundle: bundle,
      stats: stats,
    );
    // known 1 of Safety(2) + 0 of Service(1) = 1/3
    expect(percent.round(), 33);

    stats = await repo.updateReviewResult(
      language: 'English',
      category: 'Safety',
      reviewedWordIds: [ids.first],
      stillUnknownWordIds: const [],
    );
    expect(stats.forCategory('English', 'Safety').isMastered, isTrue);
  });
}
