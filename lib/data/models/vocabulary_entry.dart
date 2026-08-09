import '../../core/utils/word_compare.dart';
import '../../core/utils/word_match.dart';

/// Words 시트 행과 1:1 매핑되는 단어 사전 항목.
class VocabularyEntry {
  final String term;
  final String meaning;
  final String language;
  final String? pronunciation;
  final String? description;
  final String? category;
  final int popular;
  final bool important;

  const VocabularyEntry({
    required this.term,
    required this.meaning,
    this.language = 'English',
    this.pronunciation,
    this.description,
    this.category,
    this.popular = 0,
    this.important = false,
  });

  factory VocabularyEntry.fromJson(Map<String, dynamic> json) {
    return VocabularyEntry(
      term: (json['term'] ?? json['word'] ?? '') as String,
      meaning: (json['meaning'] ?? '') as String,
      language: (json['language'] ?? 'English') as String,
      pronunciation: _optionalString(json['pronunciation']),
      description: _optionalString(json['description']),
      category: _optionalString(json['category']),
      popular: _parseInt(json['popular']),
      important: _parseImportant(json['important']),
    );
  }

  static bool _parseImportant(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'yes' ||
        normalized == 'true' ||
        normalized == '1' ||
        normalized == 'y';
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'meaning': meaning,
        'language': language,
        if (pronunciation != null) 'pronunciation': pronunciation,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        'popular': popular,
        'important': important ? 'Yes' : 'No',
      };
}

/// 정규화된 term → [VocabularyEntry] 인덱스.
class VocabularyIndex {
  final Map<String, VocabularyEntry> _byTerm;
  final List<VocabularyEntry> _entries;

  VocabularyIndex(this._byTerm, this._entries);

  factory VocabularyIndex.fromEntries(List<VocabularyEntry> entries) {
    final map = <String, VocabularyEntry>{};
    for (final entry in entries) {
      final key = normalizeTerm(entry.term);
      if (key.isNotEmpty) map[key] = entry;
    }
    return VocabularyIndex(map, entries);
  }

  static String normalizeTerm(String term) {
    final words =
        WordCompare.splitWords(term).map(WordMatch.cleanToken).join(' ');
    return words.trim();
  }

  List<VocabularyEntry> get entries => _entries;

  bool get isEmpty => _byTerm.isEmpty;
}
