/// 단어 비교용 전처리·분리 유틸.
class WordCompare {
  WordCompare._();

  /// `/`·아포스트로피·괄호 등 STT에 안 나오는 기호는 비교에서 무시.
  static final RegExp _punctuation = RegExp(r'''[.,!?;:"'’/`~\-()\[\]{}]''');

  static bool isCjkLanguage(String language) =>
      language == 'Japanese' || language == 'Chinese';

  /// 공백 기준 분리. 연속 공백으로 생기는 빈 토큰은 제거한다.
  static List<String> splitWords(String text) =>
      text.split(' ').where((w) => w.isNotEmpty).toList();

  /// 언어별 토큰 분리.
  ///
  /// 일본어는 가라오케·매칭 모두 글자 단위(공백 무시). 중국어는 공백 있으면 어절,
  /// 없으면 글자. 그 외는 공백 단위.
  static List<String> splitTokens(String text, {String language = 'English'}) {
    if (language == 'Japanese') {
      return splitCharacters(text)
          .where((c) => c.trim().isNotEmpty)
          .toList();
    }
    if (language == 'Chinese') {
      if (text.contains(' ')) return splitWords(text);
      return splitCharacters(text);
    }
    return splitWords(text);
  }

  /// UTF-16 [offset]이 가리키는 [splitTokens] 인덱스.
  static int? tokenIndexForCodeUnitOffset(
    String text,
    int offset, {
    String language = 'English',
  }) {
    if (text.isEmpty) return null;
    final o = offset.clamp(0, text.length);

    if (language == 'Japanese') {
      var tokenIdx = 0;
      var i = 0;
      while (i < text.length) {
        if (text[i].trim().isEmpty) {
          i++;
          continue;
        }
        final cu = text.codeUnitAt(i);
        final len =
            (cu >= 0xD800 && cu <= 0xDBFF && i + 1 < text.length) ? 2 : 1;
        final end = i + len;
        if (o < end) return tokenIdx;
        i = end;
        tokenIdx++;
      }
      return tokenIdx > 0 ? tokenIdx - 1 : 0;
    }

    if (isCjkLanguage(language) && !text.contains(' ')) {
      var tokenIdx = 0;
      var i = 0;
      while (i < text.length) {
        final cu = text.codeUnitAt(i);
        final len =
            (cu >= 0xD800 && cu <= 0xDBFF && i + 1 < text.length) ? 2 : 1;
        final end = i + len;
        if (o < end) return tokenIdx;
        i = end;
        tokenIdx++;
      }
      return tokenIdx > 0 ? tokenIdx - 1 : 0;
    }

    var i = 0;
    var wordIdx = 0;
    while (i < text.length) {
      while (i < text.length && text[i] == ' ') {
        i++;
      }
      if (i >= text.length) break;
      final start = i;
      while (i < text.length && text[i] != ' ') {
        i++;
      }
      if (o <= start || o < i) {
        return wordIdx;
      }
      wordIdx++;
    }
    return wordIdx > 0 ? wordIdx - 1 : 0;
  }

  /// 서로게이트 페어를 고려한 UTF-16 글자 단위 분리.
  static List<String> splitCharacters(String text) {
    final tokens = <String>[];
    var i = 0;
    while (i < text.length) {
      final cu = text.codeUnitAt(i);
      if (cu >= 0xD800 && cu <= 0xDBFF && i + 1 < text.length) {
        tokens.add(text.substring(i, i + 2));
        i += 2;
      } else {
        tokens.add(text[i]);
        i += 1;
      }
    }
    return tokens;
  }

  static String tokenSeparator(String language) =>
      isCjkLanguage(language) ? '' : ' ';

  static int charOffsetForTokenIndex(
    List<String> tokens,
    int tokenIndex, {
    String language = 'English',
  }) {
    if (tokenIndex <= 0) return 0;
    final sep = tokenSeparator(language);
    var offset = 0;
    for (var i = 0; i < tokenIndex && i < tokens.length; i++) {
      offset += tokens[i].length;
      if (sep.isNotEmpty) offset += sep.length;
    }
    return offset;
  }

  static int charLengthForTokenRange(
    List<String> tokens,
    int startIndex,
    int endIndex, {
    String language = 'English',
  }) {
    if (startIndex > endIndex || startIndex >= tokens.length) return 0;
    final sep = tokenSeparator(language);
    var len = 0;
    for (var i = startIndex; i <= endIndex && i < tokens.length; i++) {
      if (i > startIndex && sep.isNotEmpty) len += sep.length;
      len += tokens[i].length;
    }
    return len;
  }

  /// 비교 시에만 사용: 소문자 변환 + 문장부호 제거.
  static String normalize(String word) =>
      word.toLowerCase().replaceAll(_punctuation, '');

  /// 같은 인덱스의 정답 단어와 일치 여부.
  static bool matchesAt(
    List<String> spokenWords,
    List<String> correctWords,
    int index,
  ) {
    if (index >= correctWords.length || index >= spokenWords.length) {
      return false;
    }
    return normalize(spokenWords[index]) == normalize(correctWords[index]);
  }
}
