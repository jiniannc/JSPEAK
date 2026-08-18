/// 일본어 STT 오인식 → 기내 정답 용어 보정 맵.
///
/// 새 패턴 추가: [entries]에 `(misheard: '...', corrected: '...')` 한 줄 추가.
/// 긴 구문일수록 위쪽에 배치하면 부분 치환 충돌을 줄일 수 있다.
class JapaneseSttFixMap {
  JapaneseSttFixMap._();

  static const List<({String misheard, String corrected, String? note})> entries =
      [
    (
      misheard: '後藤直近',
      corrected: 'ご搭乗券',
      note: 'ご搭乗券(탑승권) 발음 오인식',
    ),
    (
      misheard: '搭乗券',
      corrected: 'ご搭乗券',
      note: '접두 ご 누락',
    ),
    (
      misheard: '致します',
      corrected: 'いたします',
      note: '한자 어미 → 히라가나',
    ),
    (
      misheard: '御座います',
      corrected: 'ございます',
      note: '한자 어미 → 히라가나',
    ),
    (
      misheard: '下さい',
      corrected: 'ください',
      note: '한자 → 히라가나',
    ),
    (
      misheard: '御願い',
      corrected: 'お願い',
      note: '御→お 접두',
    ),
  ];

  /// STT 원문에 보정 맵을 적용한다 (긴 패턴 우선).
  static String apply(String spoken) {
    var result = spoken;
    for (final entry in entries) {
      if (entry.misheard.isEmpty) continue;
      result = _applyEntry(result, entry.misheard, entry.corrected);
    }
    // STT가 같은 구를 연속 중복 인식하는 경우 (全てのお全てのお → 全てのお).
    return collapseImmediateDuplicates(result);
  }

  /// [corrected]가 [misheard] 앞에 접두사를 붙이는 형태(예: 搭乗券→ご搭乗券)일 때,
  /// 그 접두사가 이미 붙어 있으면 중복 적용하지 않는다 (ご搭乗券 → ごご搭乗券 방지).
  static String _applyEntry(String text, String misheard, String corrected) {
    if (!corrected.endsWith(misheard) || corrected.length <= misheard.length) {
      return text.replaceAll(misheard, corrected);
    }
    final prefix = corrected.substring(0, corrected.length - misheard.length);
    final buffer = StringBuffer();
    var idx = 0;
    while (true) {
      final found = text.indexOf(misheard, idx);
      if (found == -1) {
        buffer.write(text.substring(idx));
        break;
      }
      final alreadyPrefixed = found >= prefix.length &&
          text.substring(found - prefix.length, found) == prefix;
      buffer.write(text.substring(idx, found));
      buffer.write(alreadyPrefixed ? misheard : corrected);
      idx = found + misheard.length;
    }
    return buffer.toString();
  }

  /// 바로 이어지는 동일 부분 문자열(2글자 이상) 반복을 한 번으로 접는다.
  static String collapseImmediateDuplicates(String text) {
    if (text.length < 4) return text;

    var result = text;
    var changed = true;
    while (changed) {
      changed = false;
      final maxLen = result.length ~/ 2;
      outer:
      for (var len = maxLen < 24 ? maxLen : 24; len >= 2; len--) {
        for (var i = 0; i + 2 * len <= result.length; i++) {
          final a = result.substring(i, i + len);
          final b = result.substring(i + len, i + 2 * len);
          if (a != b) continue;
          result =
              '${result.substring(0, i + len)}${result.substring(i + 2 * len)}';
          changed = true;
          break outer;
        }
      }
    }
    return result;
  }
}
