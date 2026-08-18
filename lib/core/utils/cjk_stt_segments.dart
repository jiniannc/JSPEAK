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
  /// \u3005(々)·\u3006(〆)·\u3007(〇)·\u303B — 한자 반복부호 등 CJK 기호
  /// 블록에 있지만 실제 문자 내용인 것들(구두점이 아님)도 포함해야 한다.
  /// 이게 빠지면 정답에 「色々」처럼 々이 있을 때, 완벽히 맞게 발음해도
  /// 비교 단계에서 々이 조용히 지워져 "누락"으로 오판된다.
  static final RegExp _targetChar = RegExp(
    r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\u3400-\u4DBF\u3005\u3006\u3007\u303B]',
  );

  static bool isTargetLanguage(String language) =>
      language == 'Japanese' || language == 'Chinese';

  static bool isTargetChar(String char) => _targetChar.hasMatch(char);

  static final RegExp _latinLetter = RegExp(r'[A-Za-z]');

  /// 정답 문장에 등장하는 라틴 단어 (QR, Visit, Japan, Web 등) — 등장 순서 유지.
  static List<String> latinWordsInReference(String? referenceText) {
    if (referenceText == null || referenceText.trim().isEmpty) {
      return const [];
    }
    final words = <String>[];
    for (final match in RegExp(r'[A-Za-z]+').allMatches(referenceText)) {
      final run = match.group(0)!;
      if (run.length >= 2) {
        words.add(run.toUpperCase());
      }
    }
    return words;
  }

  /// 정답 문장에 등장하는 라틴 약어 집합 (QR, ID 등).
  static Set<String> latinAcronymsInReference(String? referenceText) =>
      latinWordsInReference(referenceText).toSet();

  /// STT/정답의 라틴 연속 구간을 정답 라틴 단어열에 맞춰 유지.
  /// - `Visit Japan Web` → `VISITJAPANWEB` (공백 제거·대문자)
  /// - `anWEB` → `WEB` (정답에 있는 조각만 유지, 잡음 제거)
  static String matchLatinRunAgainstReference(
    String runCompactUpper,
    List<String> referenceWords,
  ) {
    if (runCompactUpper.isEmpty || referenceWords.isEmpty) return '';

    // 정답 단어의 연속 연결이 run 전체와 일치하면 그대로 채택.
    for (var start = 0; start < referenceWords.length; start++) {
      var concat = '';
      for (var end = start; end < referenceWords.length; end++) {
        concat += referenceWords[end];
        if (concat == runCompactUpper) return concat;
        if (concat.length > runCompactUpper.length) break;
      }
    }

    // 부분 일치: 앞에서부터 정답 단어를 탐욕적으로 붙이고, 모르는 글자는 건너뜀.
    final kept = StringBuffer();
    var i = 0;
    while (i < runCompactUpper.length) {
      String? best;
      for (final w in referenceWords) {
        if (runCompactUpper.startsWith(w, i) &&
            (best == null || w.length > best.length)) {
          best = w;
        }
      }
      if (best != null) {
        kept.write(best);
        i += best.length;
      } else {
        i++;
      }
    }
    return kept.toString();
  }

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
  /// [referenceText]에 있는 라틴 약어(QR 등)는 STT에 있으면 유지한다.
  static String extractTargetScript(
    String spoken,
    String language, {
    String? referenceText,
  }) {
    if (!isTargetLanguage(language)) return spoken;
    if (spoken.isEmpty) return spoken;

    final referenceWords = latinWordsInReference(referenceText);
    if (referenceWords.isEmpty) {
      return parse(spoken, language)
          .where((s) => s.isTargetScript)
          .map((s) => s.text)
          .join();
    }

    final buffer = StringBuffer();
    var i = 0;
    while (i < spoken.length) {
      final ch = spoken[i];
      if (isTargetChar(ch)) {
        var j = i + 1;
        while (j < spoken.length && isTargetChar(spoken[j])) {
          j++;
        }
        buffer.write(spoken.substring(i, j));
        i = j;
        continue;
      }

      if (_latinLetter.hasMatch(ch)) {
        var j = i;
        while (j < spoken.length) {
          if (_latinLetter.hasMatch(spoken[j])) {
            j++;
          } else if (spoken[j] == ' ' &&
              j + 1 < spoken.length &&
              _latinLetter.hasMatch(spoken[j + 1])) {
            j++;
          } else {
            break;
          }
        }
        final run =
            spoken.substring(i, j).replaceAll(RegExp(r'\s+'), '').toUpperCase();
        final kept = matchLatinRunAgainstReference(run, referenceWords);
        if (kept.isNotEmpty) {
          buffer.write(kept);
        }
        i = j;
        continue;
      }

      i++;
    }
    return buffer.toString();
  }
}
