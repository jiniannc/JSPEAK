/// 일본어 아라비아 숫자 → 히라가나 읽기 (STT·정답 비교용).
class JapaneseNumberNormalizer {
  JapaneseNumberNormalizer._();

  static final RegExp _digitRun = RegExp(r'[0-9０-９]+');

  /// 문장 속 숫자 연속 구간을 일본어 히라가나 읽기로 바꾼다.
  /// (예: `110` → `ひゃくじゅう`, `70` → `ななじゅう`)
  static String expandDigitsInText(String text) {
    return expandWithMap(text).expanded;
  }

  /// 숫자 확장 + 확장 글자→원문 구간 매핑 (diff UI에서 `110` 표시 유지용).
  static JapaneseTextExpansion expandWithMap(String text) {
    if (text.isEmpty) {
      return JapaneseTextExpansion(
        original: text,
        expanded: text,
        expandedToOriginal: const [],
      );
    }

    final buffer = StringBuffer();
    final ranges = <ExpandedCharOrigin>[];

    var i = 0;
    while (i < text.length) {
      final match = _digitRun.matchAsPrefix(text, i);
      if (match != null) {
        final origStart = i;
        final origEnd = i + match.group(0)!.length;
        final digits = _toAsciiDigits(match.group(0)!);
        final value = int.tryParse(digits);
        final reading =
            value == null ? match.group(0)! : integerToHiragana(value);
        for (var j = 0; j < reading.length; j++) {
          ranges.add(ExpandedCharOrigin(origStart: origStart, origEnd: origEnd));
        }
        buffer.write(reading);
        i = origEnd;
        continue;
      }

      ranges.add(ExpandedCharOrigin(origStart: i, origEnd: i + 1));
      buffer.write(text[i]);
      i++;
    }

    return JapaneseTextExpansion(
      original: text,
      expanded: buffer.toString(),
      expandedToOriginal: ranges,
    );
  }

  /// 확장 문자열 [expStart, expEnd) 구간에 대응하는 원문 슬라이스.
  static String originalSliceForExpandedRange(
    JapaneseTextExpansion expansion,
    int expStart,
    int expEnd,
  ) {
    if (expStart < 0 || expEnd <= expStart) return '';
    final map = expansion.expandedToOriginal;
    if (expStart >= map.length) return '';
    final clampedEnd = expEnd.clamp(expStart + 1, map.length);
    final origStart = map[expStart].origStart;
    final origEnd = map[clampedEnd - 1].origEnd;
    return expansion.original.substring(origStart, origEnd);
  }

  static String _toAsciiDigits(String input) {
    final buffer = StringBuffer();
    for (final code in input.runes) {
      if (code >= 0xFF10 && code <= 0xFF19) {
        buffer.writeCharCode(code - 0xFF10 + 0x30);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// 0~9999 범위 정수 → 히라가나 (기내 혈압·체온 등 실무 범위).
  static String integerToHiragana(int n) {
    if (n < 0 || n > 9999) return n.toString();
    if (n == 0) return 'ぜろ';

    final parts = <String>[];

    final thousands = n ~/ 1000;
    if (thousands > 0) {
      parts.add(_thousands(thousands));
      n %= 1000;
    }

    final hundreds = n ~/ 100;
    if (hundreds > 0) {
      parts.add(_hundreds(hundreds));
      n %= 100;
    }

    if (n > 0) {
      parts.add(_under100(n));
    }

    return parts.join();
  }

  static String _under100(int n) {
    if (n == 0) return '';
    if (n < 10) return _digit(n);
    if (n == 10) return 'じゅう';
    if (n < 20) return 'じゅう${_digit(n - 10)}';
    final tens = n ~/ 10;
    final ones = n % 10;
    if (ones == 0) return '${_digit(tens)}じゅう';
    return '${_digit(tens)}じゅう${_digit(ones)}';
  }

  static String _hundreds(int n) {
    return switch (n) {
      1 => 'ひゃく',
      2 => 'にひゃく',
      3 => 'さんびゃく',
      4 => 'よんひゃく',
      5 => 'ごひゃく',
      6 => 'ろっぴゃく',
      7 => 'ななひゃく',
      8 => 'はっぴゃく',
      9 => 'きゅうひゃく',
      _ => '${_digit(n)}ひゃく',
    };
  }

  static String _thousands(int n) {
    return switch (n) {
      1 => 'せん',
      2 => 'にせん',
      3 => 'さんぜん',
      4 => 'よんせん',
      5 => 'ごせん',
      6 => 'ろっせん',
      7 => 'ななせん',
      8 => 'はっせん',
      9 => 'きゅうせん',
      _ => '${_digit(n)}せん',
    };
  }

  static String _digit(int n) {
    return switch (n) {
      1 => 'いち',
      2 => 'に',
      3 => 'さん',
      4 => 'よん',
      5 => 'ご',
      6 => 'ろく',
      7 => 'なな',
      8 => 'はち',
      9 => 'きゅう',
      _ => '',
    };
  }
}

class ExpandedCharOrigin {
  final int origStart;
  final int origEnd;

  const ExpandedCharOrigin({required this.origStart, required this.origEnd});
}

class JapaneseTextExpansion {
  final String original;
  final String expanded;
  final List<ExpandedCharOrigin> expandedToOriginal;

  const JapaneseTextExpansion({
    required this.original,
    required this.expanded,
    required this.expandedToOriginal,
  });
}
