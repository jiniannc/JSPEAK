import 'word_compare.dart';

/// 영어 발음 diff·채점용 토큰 정규화 — QR 등 약어·STT 분리 토큰 보정.
class EnglishPronunciationTokens {
  EnglishPronunciationTokens._();

  static const acronyms = {
    'QR',
    'ID',
    'VIP',
    'OK',
    'PC',
    'ATM',
    'GPS',
    'USB',
  };

  static const _homophoneToAcronym = {
    'queue': 'QR',
    'cue': 'QR',
  };

  static List<String> mergeTokens(List<String> words) {
    if (words.isEmpty) return words;
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      if (i + 1 < words.length) {
        final first = _lettersOnly(words[i]);
        final second = _lettersOnly(words[i + 1]);
        if (first.length == 1 && second.length == 1) {
          final merged = '${first}${second}'.toUpperCase();
          if (acronyms.contains(merged)) {
            out.add(_withTrailingPunct(merged, words[i + 1]));
            i += 2;
            continue;
          }
        }
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static String mergeInText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    return mergeTokens(WordCompare.splitWords(trimmed)).join(' ');
  }

  /// 인식 문장 표시용 — 첫 글자 대문자, 원문 끝 문장 부호(`.`, `?` 등) 미러링.
  static String formatSpokenSentence(String spoken, String target) {
    final merged = mergeInText(spoken);
    if (merged.isEmpty) return merged;

    final result = capitalizeFirstLetter(merged);
    return mirrorTrailingPunctuation(result, target);
  }

  /// 원문 끝 문장 부호 (`.`, `?`, `!` 등). 없으면 null.
  static String? trailingPunctuationFromTarget(String target) {
    final match = RegExp(r'([.?!]+)$').firstMatch(target.trim());
    return match?.group(1);
  }

  static String mirrorTrailingPunctuation(String text, String target) {
    final punct = trailingPunctuationFromTarget(target);
    if (punct == null) return text;
    return applyTrailingPunctuation(text, punct);
  }

  static String applyTrailingPunctuation(String text, String punct) {
    if (text.endsWith(punct)) return text;
    final stripped = text.replaceAll(RegExp(r'[.?!]+$'), '');
    if (stripped.isEmpty) return text;
    return '$stripped$punct';
  }

  static String capitalizeFirstLetter(String text) {
    final match = RegExp(r'[A-Za-z]').firstMatch(text);
    if (match == null) return text;
    final i = match.start;
    return '${text.substring(0, i)}${text[i].toUpperCase()}${text.substring(i + 1)}';
  }

  static bool areEquivalent(String a, String b) {
    return canonicalKey(a) == canonicalKey(b);
  }

  static String canonicalKey(String word) {
    final letters = _lettersOnly(word).toUpperCase();
    if (letters.isEmpty) return WordCompare.normalize(word);

    if (acronyms.contains(letters)) return letters;

    final homophone = _homophoneToAcronym[WordCompare.normalize(word)];
    if (homophone != null) return homophone;

    return WordCompare.normalize(word);
  }

  static String _lettersOnly(String word) =>
      word.replaceAll(RegExp(r'[^A-Za-z]'), '');

  static String _withTrailingPunct(String merged, String sourceWord) {
    final match = RegExp(r'([.,!?;:]+)$').firstMatch(sourceWord);
    final punct = match?.group(1) ?? '';
    return '$merged$punct';
  }
}
