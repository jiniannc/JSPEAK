import '../../data/models/vocabulary_entry.dart';

enum SearchMatchTier { none, secondary, primary }

/// 사전·문장 검색용 텍스트 정규화·부분 일치.
class SearchTextMatch {
  SearchTextMatch._();

  static final RegExp _hangul = RegExp(r'^[가-힣]+$');
  static final RegExp _whitespace = RegExp(r'\s+');

  static String _lower(String text) => text.trim().toLowerCase();

  static String compact(String text) =>
      _lower(text).replaceAll(_whitespace, '');

  /// 공백 차이를 무시한 부분 일치 (보조배터리 ↔ 보조 배터리).
  static bool containsNormalized(String haystack, String query) {
    final q = _lower(query);
    if (q.isEmpty) return false;
    final h = haystack.toLowerCase();
    if (h.contains(q)) return true;
    return compact(haystack).contains(compact(query));
  }

  /// 짧은 한글 검색어는 description만 맞는 항목을 제외해 오탐을 줄인다.
  static bool allowDescriptionOnlyMatch(String query) {
    final q = query.trim();
    if (q.isEmpty) return false;
    if (_hangul.hasMatch(q) && q.length <= 3) return false;
    return true;
  }

  static SearchMatchTier vocabularyMatchTier(VocabularyEntry entry, String query) {
    final q = query.trim();
    if (q.isEmpty) return SearchMatchTier.none;

    for (final field in [
      entry.term,
      entry.meaning,
      entry.pronunciation ?? '',
      entry.synonym ?? '',
    ]) {
      if (field.trim().isEmpty) continue;
      if (containsNormalized(field, q)) return SearchMatchTier.primary;
    }

    final description = entry.description ?? '';
    if (description.trim().isNotEmpty &&
        allowDescriptionOnlyMatch(q) &&
        containsNormalized(description, q)) {
      return SearchMatchTier.secondary;
    }

    return SearchMatchTier.none;
  }

  static bool vocabularyMatches(VocabularyEntry entry, String query) =>
      vocabularyMatchTier(entry, query) != SearchMatchTier.none;

  static bool sentenceFieldMatches(String field, String query) =>
      containsNormalized(field, query);
}
