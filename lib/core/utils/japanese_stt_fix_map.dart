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
  ];

  /// STT 원문에 보정 맵을 적용한다 (긴 패턴 우선).
  static String apply(String spoken) {
    var result = spoken;
    for (final entry in entries) {
      if (entry.misheard.isEmpty) continue;
      result = result.replaceAll(entry.misheard, entry.corrected);
    }
    return result;
  }
}
