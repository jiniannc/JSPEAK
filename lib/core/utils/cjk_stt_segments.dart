/// STT 결과에서 대상 문자(일본어·중국어)와 발음표기(로마字/병음 등)를 분리.
class CjkSttSegment {  final String text;
  final bool isTargetScript;
  final int start;
  final int end;

  const CjkSttSegment({
    required this.text,
    required this.isTargetScript,
    required this.start,
    required this.end,
  });
}

class CjkSttSegments {
  CjkSttSegments._();

  /// 히라가나·カタカナ·漢字·중국어 한자.
  static final RegExp _targetChar = RegExp(
    r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\u3400-\u4DBF]',
  );

  static bool isTargetLanguage(String language) =>
      language == 'Japanese' || language == 'Chinese';

  static bool isTargetChar(String char) => _targetChar.hasMatch(char);

  /// STT 원문을 [대상 문자] / [발음표기] 세그먼트로 분리.
  static List<CjkSttSegment> parse(String spoken, String language) {
    if (!isTargetLanguage(language) || spoken.isEmpty) {
      return [
        CjkSttSegment(
          text: spoken,
          isTargetScript: true,
          start: 0,
          end: spoken.length,
        ),
      ];
    }

    final segments = <CjkSttSegment>[];
    var i = 0;
    while (i < spoken.length) {
      final char = spoken[i];
      final isTarget = isTargetChar(char);
      var j = i + 1;
      while (j < spoken.length && isTargetChar(spoken[j]) == isTarget) {
        j++;
      }
      segments.add(
        CjkSttSegment(
          text: spoken.substring(i, j),
          isTargetScript: isTarget,
          start: i,
          end: j,
        ),
      );
      i = j;
    }
    return segments;
  }

  /// 채점·비교용 — 발음표기(로마字/병음/한글 표기) 제거.
  static String extractTargetScript(String spoken, String language) {
    if (!isTargetLanguage(language)) return spoken;
    return parse(spoken, language)
        .where((s) => s.isTargetScript)
        .map((s) => s.text)
        .join();
  }
}
