import 'vocabulary_entry.dart';

/// 스와이프 복습 카드용 단어 모델.
class WordModel {
  final String id;
  final String language; // EN | JA | ZH
  final String word;
  final String? pronunciation;
  final String meaning;
  final String description;

  const WordModel({
    required this.id,
    required this.language,
    required this.word,
    this.pronunciation,
    required this.meaning,
    this.description = '',
  });

  /// 시트/API 언어명 → 짧은 코드.
  static String languageCode(String sheetLanguage) {
    switch (sheetLanguage) {
      case 'Japanese':
      case 'JA':
      case 'ja':
        return 'JA';
      case 'Chinese':
      case 'ZH':
      case 'zh':
        return 'ZH';
      case 'English':
      case 'EN':
      case 'en':
      default:
        return 'EN';
    }
  }

  /// 짧은 코드 → 시트/API 언어명.
  static String sheetLanguage(String code) {
    switch (code.toUpperCase()) {
      case 'JA':
        return 'Japanese';
      case 'ZH':
        return 'Chinese';
      case 'EN':
      default:
        return 'English';
    }
  }

  bool get showsPronunciation =>
      language == 'JA' || language == 'ZH';

  factory WordModel.fromVocabularyEntry(
    VocabularyEntry entry, {
    String? id,
  }) {
    final code = languageCode(entry.language);
    final term = entry.term.trim();
    return WordModel(
      id: id ?? '${code}_${term}_${entry.meaning}',
      language: code,
      word: term,
      // 영어는 요구사항상 발음 비노출 (IPA가 있어도 null 취급)
      pronunciation: code == 'EN' ? null : entry.pronunciation,
      meaning: entry.meaning,
      description: entry.description ?? '',
    );
  }

  WordModel copyWith({
    String? id,
    String? language,
    String? word,
    String? pronunciation,
    String? meaning,
    String? description,
  }) {
    return WordModel(
      id: id ?? this.id,
      language: language ?? this.language,
      word: word ?? this.word,
      pronunciation: pronunciation ?? this.pronunciation,
      meaning: meaning ?? this.meaning,
      description: description ?? this.description,
    );
  }

  /// 사전 즐겨찾기(`dictionaryFavoritesProvider`) 연동용.
  VocabularyEntry toVocabularyEntry({String? category}) {
    return VocabularyEntry(
      term: word,
      meaning: meaning,
      language: sheetLanguage(language),
      pronunciation: pronunciation,
      description: description.trim().isEmpty ? null : description,
      category: category,
    );
  }
}
