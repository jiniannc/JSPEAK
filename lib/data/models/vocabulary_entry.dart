import '../../core/utils/word_compare.dart';
import '../../core/utils/word_match.dart';
import '../../core/utils/chapter_asset_path.dart';

/// Words 시트 행과 1:1 매핑되는 단어 사전 항목.
class VocabularyEntry {
  final String term;
  final String meaning;
  final String language;
  final int chapterNo;
  final String? pronunciation;
  final String? description;
  final String? category;
  final String? chapterImage;
  final String? synonym;
  final int popular;
  final bool important;

  const VocabularyEntry({
    required this.term,
    required this.meaning,
    this.language = 'English',
    this.chapterNo = 1,
    this.pronunciation,
    this.description,
    this.category,
    this.chapterImage,
    this.synonym,
    this.popular = 0,
    this.important = false,
  });

  factory VocabularyEntry.fromJson(Map<String, dynamic> json) {
    final imageRaw = _optionalString(json['chapter_image']) ?? '';
    final resolvedImage = resolveChapterAssetPath(imageRaw);

    return VocabularyEntry(
      term: (json['term'] ?? json['word'] ?? '') as String,
      meaning: (json['meaning'] ?? '') as String,
      language: (json['language'] ?? 'English') as String,
      chapterNo: _parseChapterNo(json['chapter_no']),
      pronunciation: _optionalString(json['pronunciation']),
      description: _optionalString(json['description']),
      category: _optionalString(json['category']),
      chapterImage: resolvedImage.isEmpty ? null : resolvedImage,
      synonym: _optionalSynonym(json),
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

  static String? _optionalSynonym(Map<String, dynamic> json) {
    final raw = json['synonym'] ?? json['synonyms'] ?? json['related'];
    if (raw == null) return null;
    if (raw is List) {
      for (final item in raw) {
        final s = item?.toString().trim();
        if (s != null && s.isNotEmpty) return s;
      }
      return null;
    }
    return _optionalString(raw);
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  static int _parseChapterNo(Object? value) {
    final parsed = _parseInt(value);
    return parsed <= 0 ? 1 : parsed;
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'meaning': meaning,
        'language': language,
        'chapter_no': chapterNo,
        if (pronunciation != null) 'pronunciation': pronunciation,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (chapterImage != null) 'chapter_image': chapterImage,
        if (synonym != null) 'synonym': synonym,
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
