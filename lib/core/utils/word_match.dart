/// 사전 단어 ↔ 문장 토큰 유연 매칭 (복수형, 괄호, 문장부호).
class WordMatch {
  WordMatch._();

  static final RegExp _parenthetical = RegExp(r'\([^)]*\)');
  static final RegExp _punctuation = RegExp(r'[.,!?;:]+');

  /// `crutches(cane)` → `crutches`, `pass.` → `pass`
  static String cleanToken(String raw) {
    var token = raw.toLowerCase();
    token = token.replaceAll(_parenthetical, '');
    token = token.replaceAll(_punctuation, '');
    return token.trim();
  }

  /// 기본 영어 복수형 → 단수형 (crutches → crutch).
  static String singularize(String word) {
    if (word.length < 3) return word;

    if (word.endsWith('ies') && word.length > 4) {
      return '${word.substring(0, word.length - 3)}y';
    }

    if (word.endsWith('ches') ||
        word.endsWith('shes') ||
        word.endsWith('ses') ||
        word.endsWith('xes') ||
        word.endsWith('zes')) {
      return word.substring(0, word.length - 2);
    }

    if (word.endsWith('es') && word.length > 3) {
      final stem = word.substring(0, word.length - 2);
      if (stem.endsWith('ch') ||
          stem.endsWith('sh') ||
          stem.endsWith('s') ||
          stem.endsWith('x') ||
          stem.endsWith('z') ||
          stem.endsWith('o')) {
        return stem;
      }
    }

    if (word.endsWith('s') && !word.endsWith('ss') && word.length > 2) {
      return word.substring(0, word.length - 1);
    }

    return word;
  }

  static bool flexibleMatch(String sentenceToken, String dictionaryWord) {
    final s = cleanToken(sentenceToken);
    final d = cleanToken(dictionaryWord);
    if (s.isEmpty || d.isEmpty) return false;
    if (s == d) return true;
    if (singularize(s) == d) return true;
    if (s == singularize(d)) return true;
    if (s == '${d}s' || s == '${d}es') return true;
    return false;
  }
}
