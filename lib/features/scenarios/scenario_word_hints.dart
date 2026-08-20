import '../../core/utils/answer_blank_hints.dart';
import '../../data/models/vocabulary_entry.dart';

/// 빈칸(주요) 단어 + Words 시트 조회 결과.
class ScenarioWordHint {
  final String term;
  final String? meaning;
  final String? description;

  const ScenarioWordHint({
    required this.term,
    this.meaning,
    this.description,
  });

  factory ScenarioWordHint.fromEntry(String term, VocabularyEntry entry) {
    return ScenarioWordHint(
      term: term,
      meaning: entry.meaning.trim().isEmpty ? null : entry.meaning.trim(),
      description: entry.description?.trim().isEmpty ?? true
          ? null
          : entry.description!.trim(),
    );
  }

  factory ScenarioWordHint.unmatched(String term) =>
      ScenarioWordHint(term: term);
}

List<ScenarioWordHint> resolveBlankWordHints({
  required VocabularyIndex? index,
  required String correct,
  required String blankFrame,
  required String language,
}) {
  final keyRuns = AnswerBlankHints.contiguousKeyRuns(
    correct: correct,
    blankFrame: blankFrame,
    language: language,
  );
  if (keyRuns.isEmpty) return const [];

  return [
    for (final run in keyRuns)
      () {
        final phrase = AnswerBlankHints.runAnswerText(
          correct: correct,
          blankFrame: blankFrame,
          language: language,
          keyIndices: run,
        );
        final entry = index?.lookupTerm(phrase, language: language);
        if (entry != null) {
          return ScenarioWordHint.fromEntry(phrase, entry);
        }
        return ScenarioWordHint.unmatched(phrase);
      }(),
  ];
}
