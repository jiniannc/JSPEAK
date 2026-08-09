/// 단어 비교용 전처리·분리 유틸.
class WordCompare {
  WordCompare._();

  static final RegExp _punctuation = RegExp(r'[.,!?]');

  /// 비교 시에만 사용: 소문자 변환 + 문장부호 제거.
  static String normalize(String word) =>
      word.toLowerCase().replaceAll(_punctuation, '');

  /// 공백 기준 분리. 연속 공백으로 생기는 빈 토큰은 제거한다.
  static List<String> splitWords(String text) =>
      text.split(' ').where((w) => w.isNotEmpty).toList();

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
