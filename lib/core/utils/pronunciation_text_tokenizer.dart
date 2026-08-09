import 'cjk_pronunciation_phrase.dart';
import 'cjk_stt_segments.dart';
import 'scenario_answer_compare.dart';
import 'word_compare.dart';

/// 발음 diff·정렬용 언어별 텍스트 토큰 분리.
class PronunciationTextTokenizer {
  PronunciationTextTokenizer._();

  static final RegExp _cjkClauseDelimiter = RegExp(r'[、，,]');

  static bool hasSlashSegments(String text) => text.contains('/');

  static List<String> splitSlashSegments(String text) => text
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  static String prepareSpokenForCompare(String spoken, String language) {
    if (!CjkSttSegments.isTargetLanguage(language)) return spoken.trim();
    final preprocessed = language == 'Japanese'
        ? ScenarioAnswerCompare.preprocessSpoken(spoken, language: language)
        : spoken;
    return CjkSttSegments.extractTargetScript(preprocessed, language);
  }

  static List<String> tokenizeForCompare(
    String text, {
    required String language,
    required bool isSpoken,
  }) {
    final raw =
        isSpoken ? prepareSpokenForCompare(text, language) : text.trim();
    return tokenize(raw, language: language);
  }

  static List<String> tokenize(String text, {required String language}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    if (hasSlashSegments(trimmed)) {
      return splitSlashSegments(trimmed);
    }

    if (CjkSttSegments.isTargetLanguage(language)) {
      return _tokenizeCjkSegment(trimmed, language);
    }

    return WordCompare.splitWords(trimmed);
  }

  /// 슬래시 구간 내부 — CJK는 글자 단위, 영어는 공백 단위.
  static List<String> tokenizeSegment(String segment, {required String language}) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) return [];

    if (CjkSttSegments.isTargetLanguage(language)) {
      return _tokenizeCjkSegment(trimmed, language);
    }

    return WordCompare.splitWords(trimmed);
  }

  static List<String> _tokenizeCjkSegment(String segment, String language) {
    return CjkPronunciationPhraseBuilder.segmentSurface(
      segment,
      language: language,
    );
  }

  static List<String> _meaningfulChars(String text, String language) {
    return CjkPronunciationPhraseBuilder.segmentSurface(
      text,
      language: language,
    );
  }
}
