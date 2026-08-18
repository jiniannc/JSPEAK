import 'package:flutter/material.dart';

import '../../data/models/sentence.dart';
import '../../data/models/vocabulary_entry.dart';

/// 기내 사전 — CJK 한글 발음(pronunciation) 노출 규칙.
abstract final class DictionaryPronunciationDisplay {
  static const pronunciationColor = Color(0xFF94A3B8);
  static const koreanTranslationColor = Color(0xFF475569);

  static bool isCjkLanguage(String language) =>
      language == 'Japanese' || language == 'Chinese';

  static bool showsWordPronunciation(VocabularyEntry entry) {
    final pronunciation = entry.pronunciation?.trim() ?? '';
    return isCjkLanguage(entry.language) && pronunciation.isNotEmpty;
  }

  static String wordPronunciation(VocabularyEntry entry) =>
      entry.pronunciation?.trim() ?? '';

  static bool showsSentencePronunciation(Sentence sentence) {
    return isCjkLanguage(sentence.language) &&
        sentence.pronunciation.trim().isNotEmpty;
  }

  /// 문장 카드 — 한글 발음(pronunciation) 보조 텍스트.
  static TextStyle sentencePronunciationStyle(String language) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontStyle:
            isCjkLanguage(language) ? FontStyle.normal : FontStyle.italic,
        color: pronunciationColor,
        height: 1.35,
      );

  /// 문장 카드 — 한국어 번역 본문 보조 텍스트.
  static const sentenceKoreanStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: koreanTranslationColor,
    height: 1.35,
  );
}
