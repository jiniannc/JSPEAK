/// 문장 category — `주제 (세부그룹)` 파싱.
abstract final class SentenceCategoryGrouping {
  static final _pattern = RegExp(r'^(.+?)\s*\(([^)]+)\)\s*$');

  static ({String base, String group})? parse(String category) {
    final match = _pattern.firstMatch(category.trim());
    if (match == null) return null;
    final base = match.group(1)?.trim() ?? '';
    final group = match.group(2)?.trim() ?? '';
    if (base.isEmpty || group.isEmpty) return null;
    return (base: base, group: group);
  }

  static String baseName(String category) =>
      parse(category)?.base ?? category.trim();

  static bool hasParenthetical(String category) => parse(category) != null;
}

/// 괄호 그룹 하나 — [fullCategory]로 [ContentBundle.sentencesFor] 호출.
class SentenceCategoryGroupInfo {
  final String label;
  final String fullCategory;
  final int sentenceCount;

  const SentenceCategoryGroupInfo({
    required this.label,
    required this.fullCategory,
    required this.sentenceCount,
  });
}
