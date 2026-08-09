import 'dart:math' as math;

import '../../data/models/vocabulary_entry.dart';

const kDictionaryQuickSearchChipCount = 5;

/// Words 시트 meaning(E열) — 쉼표 앞 첫 뜻만 칩 라벨로 사용.
String vocabularyChipLabel(VocabularyEntry entry) {
  final raw = entry.meaning.trim();
  if (raw.isEmpty) return entry.term.trim();
  final comma = raw.indexOf(',');
  if (comma <= 0) return raw;
  return raw.substring(0, comma).trim();
}

/// Important=true 단어 중 현재 언어 후보를 랜덤 [count]개 선택.
List<String> pickRandomImportantChipLabels({
  required List<VocabularyEntry> words,
  required String language,
  int count = kDictionaryQuickSearchChipCount,
  math.Random? random,
  List<String>? exclude,
}) {
  final rng = random ?? math.Random();
  final seen = <String>{};
  final candidates = <String>[];

  for (final entry in words) {
    if (entry.language != language || !entry.important) continue;
    final label = vocabularyChipLabel(entry);
    if (label.isEmpty || !seen.add(label)) continue;
    candidates.add(label);
  }

  if (candidates.isEmpty) return const [];

  candidates.shuffle(rng);

  if (exclude != null && exclude.isNotEmpty && candidates.length > count) {
    final filtered =
        candidates.where((label) => !exclude.contains(label)).toList();
    if (filtered.length >= count) {
      return filtered.take(count).toList();
    }
  }

  return candidates.take(math.min(count, candidates.length)).toList();
}
