import 'japanese_to_korean_converter.dart';

/// STT 표기를 정답 문장 표기로 접어, 같은 읽기의 철자 차이를 동치로 만든다.
///
/// - 한자 → 정답 가나: `お締め` + `おしめ` → `おしめ`
/// - 가나 → 정답 한자: `もの` + `者` → `者` (읽기 일치 시)
/// - 한자 오기: `酒げ` + `下げ` → `下げ`
///
/// 앞부분을 빼먹고 말한 경우(suffix)에는 정답 접두를 건너뛰고 접으며,
/// 정답 글자를 거짓으로 채워 넣지 않는다.
class JapaneseReadingFold {
  JapaneseReadingFold._();

  static final RegExp _kanji = RegExp(r'[\u4E00-\u9FFF\u3005\u3006\u3007\u303B]');
  static final RegExp _hiragana = RegExp(r'[\u3040-\u309F]');
  static final RegExp _katakana = RegExp(r'[\u30A0-\u30FF]');
  static final RegExp _latin = RegExp(r'[A-Za-z]');
  static final RegExp _punct = RegExp(r'[。、！？，,\.!?\s・…「」『』（）()]');

  static bool isKanji(String ch) => _kanji.hasMatch(ch);
  static bool isHiragana(String ch) => _hiragana.hasMatch(ch);
  static bool isKana(String ch) =>
      _hiragana.hasMatch(ch) || _katakana.hasMatch(ch);
  static bool isPunct(String ch) => _punct.hasMatch(ch);
  static bool _isJapaneseChar(String ch) =>
      isKanji(ch) || isHiragana(ch) || isKatakana(ch);
  static bool isKatakana(String ch) => _katakana.hasMatch(ch);
  static bool isLatin(String ch) => _latin.hasMatch(ch);

  /// spoken 한자(+送り仮名)를 target 위치의 가나로 치환한 문자열.
  static String fold(String spoken, String target) =>
      foldWithMap(spoken, target).folded;

  /// [folded]와 folded 각 글자가 대응되는 spoken [start,end) 구간.
  static JapaneseReadingFoldResult foldWithMap(String spoken, String target) {
    if (spoken.isEmpty || target.isEmpty) {
      return JapaneseReadingFoldResult(
        folded: spoken,
        spokenRanges: [
          for (var i = 0; i < spoken.length; i++) (start: i, end: i + 1),
        ],
      );
    }

    final out = StringBuffer();
    final ranges = <({int start, int end})>[];
    var si = 0;
    var ti = 0;

    // Visit Japan Web ← ベジットジャパンanWEB 처럼 영문 브랜드를 가타카나로
    // 인식한 경우, 뒤 일본어 본문이 같으면 접두를 정답 라틴으로 접는다.
    final brandAnchor = _findLatinBrandAnchor(spoken, target);
    if (brandAnchor != null) {
      final targetPrefix = target.substring(0, brandAnchor.targetStart);
      for (var k = 0; k < targetPrefix.length; k++) {
        final ch = targetPrefix[k];
        if (isPunct(ch)) continue;
        out.write(ch);
        ranges.add((start: 0, end: brandAnchor.spokenStart));
      }
      si = brandAnchor.spokenStart;
      ti = brandAnchor.targetStart;
    }

    while (si < spoken.length) {
      final sc = spoken[si];
      if (isPunct(sc)) {
        si++;
        continue;
      }
      while (ti < target.length && isPunct(target[ti])) {
        ti++;
      }

      if (ti < target.length && sc == target[ti]) {
        out.write(sc);
        ranges.add((start: si, end: si + 1));
        si++;
        ti++;
        continue;
      }

      // 히라가나 읽기 → 정답 한자 (もの→者). 가나 앵커보다 먼저 시도.
      if (ti < target.length && isHiragana(sc) && isKanji(target[ti])) {
        final hiraToKanji = _mapHiraganaReadingToTargetKanji(
          spoken: spoken,
          spokenStart: si,
          target: target,
          targetStart: ti,
        );
        if (hiraToKanji != null) {
          final surface = target.substring(ti, hiraToKanji.targetEnd);
          for (var k = 0; k < surface.length; k++) {
            out.write(surface[k]);
            ranges.add((start: si, end: hiraToKanji.spokenEnd));
          }
          ti = hiraToKanji.targetEnd;
          si = hiraToKanji.spokenEnd;
          continue;
        }
      }

      // 가나 불일치 — 정답 앞부분(미발화)을 건너뛰고 같은 글자를 찾는다.
      if (ti < target.length && isKana(sc) && !isKanji(sc)) {
        final anchor = _findKanaAnchor(spoken, si, target, ti);
        if (anchor != null) {
          ti = anchor;
          out.write(sc);
          ranges.add((start: si, end: si + 1));
          si++;
          ti++;
          continue;
        }
      }

      if (isKanji(sc)) {
        final kanjiStart = si;
        while (si < spoken.length && isKanji(spoken[si])) {
          si++;
        }
        final afterKanji = si;

        while (ti < target.length && isPunct(target[ti])) {
          ti++;
        }

        // STT 한자 오기(下げ→酒げ): 같은 送り仮名면 정답 표기로 접어 동치 처리.
        final kanjiVariant = _mapKanjiVariantToTarget(
          spoken: spoken,
          kanjiStart: kanjiStart,
          afterKanji: afterKanji,
          target: target,
          targetStart: ti,
        );
        if (kanjiVariant != null) {
          final surface = target.substring(ti, kanjiVariant.targetEnd);
          for (var k = 0; k < surface.length; k++) {
            out.write(surface[k]);
            ranges.add((start: kanjiStart, end: kanjiVariant.spokenEnd));
          }
          ti = kanjiVariant.targetEnd;
          si = kanjiVariant.spokenEnd;
          continue;
        }

        // 한자 → 정답 히라가나 읽기 (締め→しめ). 현재 위치만.
        final mapped = _mapKanjiRunToTargetReading(
          spoken: spoken,
          kanjiStart: kanjiStart,
          afterKanji: afterKanji,
          target: target,
          targetStart: ti,
        );

        if (mapped != null) {
          final reading = target.substring(ti, mapped.targetEnd);
          for (var k = 0; k < reading.length; k++) {
            out.write(reading[k]);
            ranges.add((start: kanjiStart, end: mapped.spokenEnd));
          }
          ti = mapped.targetEnd;
          si = mapped.spokenEnd;
          continue;
        }

        for (var k = kanjiStart; k < afterKanji; k++) {
          out.write(spoken[k]);
          ranges.add((start: k, end: k + 1));
        }
        // 매핑 실패 시 target 커서는 유지 (거짓으로 정답을 소비하지 않음)
        continue;
      }

      // 삽입/불일치 가나·기타 — spoken만 유지, target는 소비하지 않음
      out.write(sc);
      ranges.add((start: si, end: si + 1));
      si++;
    }

    return JapaneseReadingFoldResult(
      folded: out.toString(),
      spokenRanges: ranges,
    );
  }

  /// 정답 앞이 라틴 브랜드이고 STT가 가타카나/라틴 혼용으로 같은 슬롯을
  /// 채웠을 때, 공유 일본어 본문 시작 위치를 반환한다.
  static ({int spokenStart, int targetStart})? _findLatinBrandAnchor(
    String spoken,
    String target,
  ) {
    var bestLen = 0;
    int? bestSpoken;
    int? bestTarget;

    for (var ti = 0; ti < target.length; ti++) {
      if (!_isJapaneseChar(target[ti])) continue;
      var tj = ti;
      while (tj < target.length && _isJapaneseChar(target[tj])) {
        tj++;
      }
      final runLen = tj - ti;
      if (runLen < 3) continue;

      final targetPrefix = target.substring(0, ti);
      if (!_looksLikeLatinBrand(targetPrefix)) continue;

      for (var useLen = runLen; useLen >= 3; useLen--) {
        final needle = target.substring(ti, ti + useLen);
        final si = spoken.indexOf(needle);
        if (si <= 0) continue;
        final spokenPrefix = spoken.substring(0, si);
        if (!_looksLikeLoanwordStt(spokenPrefix)) continue;

        if (useLen > bestLen ||
            (useLen == bestLen && ti < (bestTarget ?? 1 << 30))) {
          bestLen = useLen;
          bestSpoken = si;
          bestTarget = ti;
        }
        break;
      }
    }

    if (bestSpoken == null || bestTarget == null) return null;
    return (spokenStart: bestSpoken, targetStart: bestTarget);
  }

  static bool _looksLikeLatinBrand(String prefix) {
    if (prefix.trim().isEmpty) return false;
    var latin = 0;
    var other = 0;
    for (var i = 0; i < prefix.length; i++) {
      final ch = prefix[i];
      if (isPunct(ch)) continue;
      if (isLatin(ch)) {
        latin++;
      } else if (_isJapaneseChar(ch)) {
        other++;
      }
    }
    return latin >= 2 && latin > other;
  }

  static bool _looksLikeLoanwordStt(String prefix) {
    if (prefix.trim().isEmpty) return false;
    var kataOrLatin = 0;
    var hiraganaKanji = 0;
    for (var i = 0; i < prefix.length; i++) {
      final ch = prefix[i];
      if (isPunct(ch)) continue;
      if (isKatakana(ch) || isLatin(ch)) {
        kataOrLatin++;
      } else if (isHiragana(ch) || isKanji(ch)) {
        hiraganaKanji++;
      }
    }
    return kataOrLatin >= 2 && kataOrLatin >= hiraganaKanji;
  }

  /// spoken[si] 가나에 대응하는 target 위치. 접두 생략을 허용하되
  /// 남은 spoken이 남은 target의 접미사로 성립할 때만 채택.
  static int? _findKanaAnchor(
    String spoken,
    int si,
    String target,
    int ti,
  ) {
    final sc = spoken[si];
    final spokenLeft = _contentLength(spoken.substring(si));
    int? best;

    for (var i = ti; i < target.length; i++) {
      if (isPunct(target[i])) continue;
      if (target[i] != sc) continue;
      final targetLeft = _contentLength(target.substring(i));
      // spoken이 target 남은 길이보다 길면 이 위치는 불가
      if (spokenLeft > targetLeft + 1) continue;
      // 접미사 정렬: spoken 길이가 target 접미에 가깝거나 같으면 우선
      best = i;
      // 더 뒤쪽 후보도 검사하되, spoken이 거의 전체를 덮는 첫/최적 후보 유지
      // → 같은 글자가 여러 번이면 남은 길이 차이가 가장 작은 것
    }

    if (best == null) return null;

    // 동일 글자 후보 중 |targetLeft - spokenLeft| 최소 선택
    var bestDelta = 1 << 30;
    int? chosen;
    for (var i = ti; i < target.length; i++) {
      if (isPunct(target[i]) || target[i] != sc) continue;
      final targetLeft = _contentLength(target.substring(i));
      if (spokenLeft > targetLeft + 1) continue;
      final delta = (targetLeft - spokenLeft).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        chosen = i;
      }
    }
    return chosen;
  }

  static int _contentLength(String text) {
    var n = 0;
    for (var i = 0; i < text.length; i++) {
      if (!isPunct(text[i])) n++;
    }
    return n;
  }

  /// STT 히라가나 읽기를 정답 한자로 접음. 예: `もの` → `者`.
  /// 변환기 읽기와 일치하고, 한자 직후 글자가 정렬될 때만 채택.
  static ({int spokenEnd, int targetEnd})? _mapHiraganaReadingToTargetKanji({
    required String spoken,
    required int spokenStart,
    required String target,
    required int targetStart,
  }) {
    if (targetStart >= target.length || !isKanji(target[targetStart])) {
      return null;
    }
    if (spokenStart >= spoken.length || !isHiragana(spoken[spokenStart])) {
      return null;
    }

    var targetKanjiEnd = targetStart;
    while (targetKanjiEnd < target.length && isKanji(target[targetKanjiEnd])) {
      targetKanjiEnd++;
    }

    final expected = JapaneseToKoreanConverter.toHiragana(
      target.substring(targetStart, targetKanjiEnd),
    );
    if (expected.isEmpty) return null;

    final spokenEnd = spokenStart + expected.length;
    if (spokenEnd > spoken.length) return null;

    final spokenReading = spoken.substring(spokenStart, spokenEnd);
    for (var i = 0; i < spokenReading.length; i++) {
      if (!isHiragana(spokenReading[i])) return null;
    }
    if (spokenReading != expected) return null;

    if (!_nextAligns(spoken, spokenEnd, target, targetKanjiEnd)) {
      return null;
    }

    return (spokenEnd: spokenEnd, targetEnd: targetKanjiEnd);
  }

  /// STT가 다른 한자를 골랐지만 이어지는 글자가 같으면 같은 단어로 본다.
  /// 예: spoken `酒げ` ≈ target `下げ` (下げ를 酒げ로 인식 — 발음 채점상 동치).
  static ({int spokenEnd, int targetEnd})? _mapKanjiVariantToTarget({
    required String spoken,
    required int kanjiStart,
    required int afterKanji,
    required String target,
    required int targetStart,
  }) {
    if (targetStart >= target.length || !isKanji(target[targetStart])) {
      return null;
    }

    var targetKanjiEnd = targetStart;
    while (targetKanjiEnd < target.length && isKanji(target[targetKanjiEnd])) {
      targetKanjiEnd++;
    }

    // 한자 직후가 같은 送り/가나로 이어지면 표기만 다른 동음 오인식으로 본다.
    if (!_nextAligns(spoken, afterKanji, target, targetKanjiEnd)) {
      return null;
    }

    return (
      spokenEnd: afterKanji,
      targetEnd: targetKanjiEnd,
    );
  }

  /// 한자 run + 最短 送り仮名를 정답 **히라가나** 읽기에 매핑.
  /// カタカナ(テーブル 등)는 읽기 후보에서 제외해 잘못된 접두 흡수를 막는다.
  static ({int spokenEnd, int targetEnd})? _mapKanjiRunToTargetReading({
    required String spoken,
    required int kanjiStart,
    required int afterKanji,
    required String target,
    required int targetStart,
  }) {
    if (targetStart >= target.length || !isHiragana(target[targetStart])) {
      return null;
    }

    var maxOku = 0;
    while (afterKanji + maxOku < spoken.length &&
        isHiragana(spoken[afterKanji + maxOku])) {
      maxOku++;
    }
    if (maxOku > 6) maxOku = 6;

    for (var end = targetStart + 1; end <= target.length; end++) {
      final ch = target[end - 1];
      if (isPunct(ch) || !isHiragana(ch)) break;
      if (_nextAligns(spoken, afterKanji, target, end)) {
        return (spokenEnd: afterKanji, targetEnd: end);
      }
    }

    for (var okuLen = 1; okuLen <= maxOku; okuLen++) {
      final oku = spoken.substring(afterKanji, afterKanji + okuLen);
      final targetEnd = _findTargetReadingEnd(
        target: target,
        targetStart: targetStart,
        okurigana: oku,
      );
      if (targetEnd == null) continue;

      final spokenEnd = afterKanji + okuLen;
      if (_nextAligns(spoken, spokenEnd, target, targetEnd)) {
        return (spokenEnd: spokenEnd, targetEnd: targetEnd);
      }
    }
    return null;
  }

  static bool _nextAligns(
    String spoken,
    int spokenPos,
    String target,
    int targetPos,
  ) {
    var sp = spokenPos;
    var tp = targetPos;
    while (sp < spoken.length && isPunct(spoken[sp])) {
      sp++;
    }
    while (tp < target.length && isPunct(target[tp])) {
      tp++;
    }
    if (sp >= spoken.length && tp >= target.length) return true;
    if (sp >= spoken.length || tp >= target.length) {
      return sp >= spoken.length && tp >= target.length;
    }
    if (spoken[sp] == target[tp]) return true;
    if (isKanji(spoken[sp]) && isKana(target[tp])) return true;
    return false;
  }

  static int? _findTargetReadingEnd({
    required String target,
    required int targetStart,
    required String okurigana,
  }) {
    if (targetStart >= target.length || okurigana.isEmpty) return null;
    if (!isHiragana(target[targetStart])) return null;

    for (var end = targetStart + 1; end <= target.length; end++) {
      final ch = target[end - 1];
      if (isPunct(ch)) break;
      if (!isHiragana(ch)) break;
      final span = target.substring(targetStart, end);
      if (span.endsWith(okurigana)) return end;
    }
    return null;
  }

  /// folded 구간 [foldStart, foldEnd) 에 대응하는 spoken 표면 문자열.
  static String spokenSurfaceForFoldRange(
    JapaneseReadingFoldResult fold,
    String spoken, {
    required int foldStart,
    required int foldEnd,
  }) {
    if (fold.spokenRanges.isEmpty || foldStart >= foldEnd) return '';
    final start = foldStart.clamp(0, fold.spokenRanges.length - 1);
    final endIdx = (foldEnd - 1).clamp(0, fold.spokenRanges.length - 1);
    final s = fold.spokenRanges[start].start;
    final e = fold.spokenRanges[endIdx].end;
    if (s >= e || s >= spoken.length) return '';
    return spoken.substring(s, e.clamp(0, spoken.length));
  }
}

class JapaneseReadingFoldResult {
  final String folded;
  final List<({int start, int end})> spokenRanges;

  const JapaneseReadingFoldResult({
    required this.folded,
    required this.spokenRanges,
  });
}
