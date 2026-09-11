import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/swipe_progress_local_datasource.dart';
import '../data/repositories/swipe_progress_repository.dart';
import 'app_language_sync.dart';

final swipeProgressLocalDataSourceProvider =
    Provider<SwipeProgressLocalDataSource>(
  (ref) => SwipeProgressLocalDataSource(),
);

final swipeProgressRepositoryProvider =
    Provider<SwipeProgressRepository>((ref) {
  return SwipeProgressRepository(
    local: ref.watch(swipeProgressLocalDataSourceProvider),
  );
});

/// 스와이프 홈 언어 선택.
class SwipeLanguageController extends Notifier<String> {
  @override
  String build() => 'English';

  void set(String language) => state = language;
}

final swipeLanguageProvider =
    NotifierProvider<SwipeLanguageController, String>(
  SwipeLanguageController.new,
);

void selectSwipeLanguage(WidgetRef ref, String language) {
  syncAppLanguage(ref, language);
}

class SwipeProgressState {
  final SwipeProgressStats stats;
  final bool loading;

  const SwipeProgressState({
    required this.stats,
    this.loading = false,
  });

  SwipeProgressState copyWith({
    SwipeProgressStats? stats,
    bool? loading,
  }) {
    return SwipeProgressState(
      stats: stats ?? this.stats,
      loading: loading ?? this.loading,
    );
  }
}

class SwipeProgressController extends Notifier<SwipeProgressState> {
  SwipeProgressRepository get _repo =>
      ref.read(swipeProgressRepositoryProvider);

  @override
  SwipeProgressState build() {
    Future.microtask(_load);
    return const SwipeProgressState(stats: SwipeProgressStats());
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true);
    final stats = await _repo.loadStats();
    state = SwipeProgressState(stats: stats);
  }

  Future<void> refresh() => _load();

  Future<void> saveCategoryResult({
    required String language,
    required String category,
    required List<String> allWordIds,
    required List<String> unknownWordIds,
  }) async {
    final stats = await _repo.saveCategoryResult(
      language: language,
      category: category,
      allWordIds: allWordIds,
      unknownWordIds: unknownWordIds,
    );
    state = SwipeProgressState(stats: stats);
  }

  Future<void> updateReviewResult({
    required String language,
    required String category,
    required List<String> reviewedWordIds,
    required List<String> stillUnknownWordIds,
  }) async {
    final stats = await _repo.updateReviewResult(
      language: language,
      category: category,
      reviewedWordIds: reviewedWordIds,
      stillUnknownWordIds: stillUnknownWordIds,
    );
    state = SwipeProgressState(stats: stats);
  }
}

final swipeProgressProvider =
    NotifierProvider<SwipeProgressController, SwipeProgressState>(
  SwipeProgressController.new,
);
