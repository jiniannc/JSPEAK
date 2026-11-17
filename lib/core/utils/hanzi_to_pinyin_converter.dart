import 'package:lpinyin/lpinyin.dart';

/// 한자 한 글자의 독음 하나 — 성조 기호 표기·성조 없는 음절·성조 번호(경성 5).
class HanziReading {
  final String marked;
  final String base;
  final int tone;

  const HanziReading({
    required this.marked,
    required this.base,
    required this.tone,
  });
}

/// 정답 글자와 STT 글자가 음절은 같고 성조만 다른 경우의 비교 정보.
class HanziToneDiff {
  final HanziReading target;
  final HanziReading spoken;

  const HanziToneDiff({required this.target, required this.spoken});
}

/// STT 중국어 한자 → 성조(Tone mark) 병음 변환·동음 판정.
class HanziToPinyinConverter {
  HanziToPinyinConverter._();

  static final RegExp _hanzi = RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF]');
  static final RegExp _toneNumber = RegExp(r'^([a-zü]+)([1-5])$');

  /// 문맥에 따라 성조가 바뀌는 글자 (一·不 변조).
  static const Set<String> _sandhiChars = {'一', '不'};

  static final Map<String, List<HanziReading>> _readingsCache = {};

  /// STT 오답 텍스트 → 성조 병음. 변환 불가 시 `null`.
  static String? transliterateOrNull(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !_hanzi.hasMatch(trimmed)) return null;

    try {
      final pinyin = PinyinHelper.getPinyinE(
        trimmed,
        separator: ' ',
        format: PinyinFormat.WITH_TONE_MARK,
      ).trim();
      if (pinyin.isEmpty) return null;
      return pinyin;
    } catch (_) {
      return null;
    }
  }

  /// 한자 한 글자의 모든 독음(다음자 포함). 첫 항목이 대표 독음. 한자가 아니면 빈 목록.
  static List<HanziReading> readingsOf(String char) =>
      _readingsCache.putIfAbsent(char, () {
        if (char.length != 1 || !_hanzi.hasMatch(char)) return const [];
        try {
          final marked =
              PinyinHelper.convertToPinyinArray(char, PinyinFormat.WITH_TONE_MARK);
          final numbered = PinyinHelper.convertToPinyinArray(
            char,
            PinyinFormat.WITH_TONE_NUMBER,
          );
          final readings = <HanziReading>[];
          for (var i = 0; i < marked.length && i < numbered.length; i++) {
            final m = _toneNumber.firstMatch(numbered[i].replaceAll('v', 'ü'));
            if (m == null) continue;
            readings.add(
              HanziReading(
                marked: marked[i],
                base: m.group(1)!,
                tone: int.parse(m.group(2)!),
              ),
            );
          }
          return readings;
        } catch (_) {
          return const [];
        }
      });

  /// 성조까지 같은 소리로 인정하는지. 경성·一/不 변조는 성조 차이를 허용한다.
  static bool _sameSound(
    String charA,
    HanziReading a,
    String charB,
    HanziReading b,
  ) {
    if (a.base != b.base) return false;
    if (a.tone == b.tone || a.tone == 5 || b.tone == 5) return true;
    return _sandhiChars.contains(charA) || _sandhiChars.contains(charB);
  }

  static bool _charHomophone(String a, String b) {
    if (a == b) return true;
    final ra = readingsOf(a);
    final rb = readingsOf(b);
    for (final x in ra) {
      for (final y in rb) {
        if (_sameSound(a, x, b, y)) return true;
      }
    }
    return false;
  }

  /// 같은 길이의 두 한자열이 글자마다 같은 소리(병음+성조)를 공유하면 `true`.
  ///
  /// STT가 같은 소리를 다른 한자로 받아쓴 경우(登机 → 灯机 등)를 정답으로 보기 위함.
  static bool isHomophone(String a, String b) {
    if (a.isEmpty || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_charHomophone(a[i], b[i])) return false;
    }
    return true;
  }

  /// 한 글자끼리 음절은 같고 성조만 다르면 그 비교 정보, 아니면 `null`.
  static HanziToneDiff? toneDiffOf(String target, String spoken) {
    if (target.length != 1 || spoken.length != 1) return null;
    if (_charHomophone(target, spoken)) return null;
    final rt = readingsOf(target);
    final rs = readingsOf(spoken);
    for (final t in rt) {
      for (final s in rs) {
        if (t.base == s.base) return HanziToneDiff(target: t, spoken: s);
      }
    }
    return null;
  }

  /// 같은 길이의 두 한자열이 글자마다 동음이거나 성조만 다르고,
  /// 그중 성조만 다른 글자가 하나 이상이면 `true`.
  static bool isToneOnlyDiff(String target, String spoken) {
    if (target.isEmpty || target.length != spoken.length) return false;
    if (isHomophone(target, spoken)) return false;
    var sawToneDiff = false;
    for (var i = 0; i < target.length; i++) {
      if (_charHomophone(target[i], spoken[i])) continue;
      if (toneDiffOf(target[i], spoken[i]) == null) return false;
      sawToneDiff = true;
    }
    return sawToneDiff;
  }

  /// STT가 들은 쪽으로 추정되는 성조 병음 (tone mark).
  ///
  /// 글자마다 성조만 다른 경우 spoken 쪽 독음을, 그 외에는 한자→병음 변환을 쓴다.
  static String? heardTonePinyin(String target, String spoken) {
    if (target.isEmpty || spoken.isEmpty) return transliterateOrNull(spoken);
    if (target.length == spoken.length && isToneOnlyDiff(target, spoken)) {
      final parts = <String>[];
      for (var i = 0; i < spoken.length; i++) {
        final diff = toneDiffOf(target[i], spoken[i]);
        if (diff != null) {
          parts.add(diff.spoken.marked);
          continue;
        }
        final readings = readingsOf(spoken[i]);
        if (readings.isNotEmpty) {
          parts.add(readings.first.marked);
        } else {
          final fallback = transliterateOrNull(spoken[i]);
          if (fallback != null) parts.add(fallback);
        }
      }
      if (parts.isNotEmpty) return parts.join(' ');
    }
    return transliterateOrNull(spoken);
  }
}
