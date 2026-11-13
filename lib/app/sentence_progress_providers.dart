import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/sentence_progress_local_datasource.dart';
import '../data/repositories/sentence_progress_repository.dart';
export 'app_language_provider.dart' show basicSentenceLanguageProvider;

import 'app_language_sync.dart';

final sentenceProgressLocalDataSourceProvider =
    Provider<SentenceProgressLocalDataSource>(
  (ref) => SentenceProgressLocalDataSource(),
);

final sentenceProgressRepositoryProvider =
    Provider<SentenceProgressRepository>((ref) {
  return SentenceProgressRepository(
    local: ref.watch(sentenceProgressLocalDataSourceProvider),
  );
});

void selectBasicSentenceLanguage(WidgetRef ref, String language) {
  syncAppLanguage(ref, language);
}

class SentenceProgressState {
  final SentenceProgressStats stats;
  final bool loading;

  const SentenceProgressState({
    required this.stats,
    this.loading = false,
  });

  SentenceProgressState copyWith({
    SentenceProgressStats? stats,
    bool? loading,
  }) {
    return SentenceProgressState(
      stats: stats ?? this.stats,
      loading: loading ?? this.loading,
    );
  }
}

class SentenceProgressController extends Notifier<SentenceProgressState> {
  SentenceProgressRepository get _repo =>
      ref.read(sentenceProgressRepositoryProvider);

  @override
  SentenceProgressState build() {
    Future.microtask(_load);
    return const SentenceProgressState(stats: SentenceProgressStats());
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true);
    final stats = await _repo.loadStats();
    state = SentenceProgressState(stats: stats);
  }

  Future<void> refresh() => _load();

  Future<void> markRead(String sentenceId) async {
    final stats = await _repo.markRead(sentenceId);
    state = SentenceProgressState(stats: stats);
  }

  Future<void> markListened(String sentenceId) async {
    final stats = await _repo.markListened(sentenceId);
    state = SentenceProgressState(stats: stats);
  }

  Future<void> recordPracticeResult({
    required String sentenceId,
    required int accuracy,
    required bool hasSpokenText,
  }) async {
    final stats = await _repo.recordPracticeResult(
      sentenceId: sentenceId,
      accuracy: accuracy,
      hasSpokenText: hasSpokenText,
    );
    state = SentenceProgressState(stats: stats);
  }
}

final sentenceProgressProvider =
    NotifierProvider<SentenceProgressController, SentenceProgressState>(
  SentenceProgressController.new,
);
