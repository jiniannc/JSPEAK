import 'hanzi_to_pinyin_converter.dart';
import 'japanese_to_korean_converter.dart';

/// CJK STT 오답 칩 서브텍스트 — 언어별 독음/병음 변환.
class CjkSpokenPhonetic {
  CjkSpokenPhonetic._();

  static String? phoneticForSpokenSurface(
    String spokenSurface, {
    required String language,
  }) {
    final trimmed = spokenSurface.trim();
    if (trimmed.isEmpty) return null;

    return switch (language) {
      'Japanese' => JapaneseToKoreanConverter.transliterateOrNull(trimmed),
      'Chinese' => HanziToPinyinConverter.transliterateOrNull(trimmed),
      _ => null,
    };
  }
}
