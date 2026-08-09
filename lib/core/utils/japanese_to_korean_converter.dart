import 'cjk_stt_segments.dart';
import 'japanese_stt_fix_map.dart';

/// STT 오답 일본어 — [한자→히라가나] → [히라가나→한글] 2단계 변환.
class JapaneseToKoreanConverter {
  JapaneseToKoreanConverter._();

  static final RegExp _hiragana = RegExp(r'[\u3040-\u309F]');
  static final RegExp _katakana = RegExp(r'[\u30A0-\u30FF]');
  static final RegExp _kanji = RegExp(r'[\u4E00-\u9FFF]');
  static final RegExp _punct = RegExp(r'[。、！？，,\.!?・…\s]');

  static const List<(String from, String to)> _phraseReadings = [
    ('確認しております', 'かくにんしております'),
    ('お一人様', 'おひとりさま'),
    ('一人様', 'ひとりさま'),
    ('ご搭乗券', 'ごとうじょうけん'),
    ('搭乗券', 'とうじょうけん'),
    ('除菌', 'じょきん'),
    ('通路側', 'つうろがわ'),
    ('黒川', 'くろかわ'),
    ('座席', 'ざせき'),
    ('御座います', 'ございます'),
    ('致します', 'いたします'),
    ('下さい', 'ください'),
    ('有り難う', 'ありがとう'),
    ('有難う', 'ありがとう'),
    ('御願い', 'おねがい'),
    ('助けて', 'たすけて'),
    ('拝見', 'はいけん'),
    ('確認', 'かくにん'),
    ('便名', 'べんめい'),
    ('瓶名', 'べんめい'),
    ('日付', 'ひづけ'),
    ('一人', 'ひとり'),
    ('お一人', 'おひとり'),
  ];

  static const Map<String, String> _kanjiReadings = {
    '除': 'じょ', '菌': 'きん', '一': 'いち', '人': 'ひと', '様': 'さま',
    '黒': 'くろ', '川': 'かわ', '通': 'つう', '路': 'ろ', '側': 'がわ',
    '座': 'ざ', '席': 'せき', '助': 'たす', '搭': 'とう', '乗': 'じょう',
    '券': 'けん', '御': 'ご', '致': 'いた', '下': 'くだ', '有': 'あ',
    '難': 'がた', '願': 'ねが', '便': 'べん', '瓶': 'びん', '名': 'めい',
    '日': 'ひ', '付': 'づ', '確': 'かく', '認': 'にん', '拝': 'はい',
    '見': 'けん', '飲': 'の', '物': 'もの', '何': 'なに', '文': 'ぶん',
    '化': 'か', '本': 'ほん', '大': 'だい', '小': 'しょう', '中': 'なか',
    '客': 'きゃく', '十': 'じゅう',
  };

  static const Map<String, String> _kanaToHangul = {
    'きゃ': '캬', 'きゅ': '큐', 'きょ': '쿄', 'ぎゃ': '갸', 'ぎゅ': '규', 'ぎょ': '교',
    'しゃ': '샤', 'しゅ': '슈', 'しょ': '쇼', 'じゃ': '자', 'じゅ': '주', 'じょ': '죠',
    'ちゃ': '챠', 'ちゅ': '츄', 'ちょ': '쵸', 'にゃ': '냐', 'にゅ': '뉴', 'にょ': '뇨',
    'ひゃ': '햐', 'ひゅ': '휴', 'ひょ': '효', 'びゃ': '뱌', 'びゅ': '뷰', 'びょ': '뵤',
    'ぴゃ': '퍄', 'ぴゅ': '퓨', 'ぴょ': '표', 'みゃ': '먀', 'みゅ': '뮤', 'みょ': '묘',
    'りゃ': '랴', 'りゅ': '류', 'りょ': '료',
    'あ': '아', 'い': '이', 'う': '우', 'え': '에', 'お': '오',
    'か': '카', 'き': '키', 'く': '쿠', 'け': '케', 'こ': '코',
    'が': '가', 'ぎ': '기', 'ぐ': '구', 'げ': '게', 'ご': '고',
    'さ': '사', 'し': '시', 'す': '스', 'せ': '세', 'そ': '소',
    'ざ': '자', 'じ': '지', 'ず': '즈', 'ぜ': '제', 'ぞ': '조',
    'た': '타', 'ち': '치', 'つ': '츠', 'て': '테', 'と': '토',
    'だ': '다', 'ぢ': '지', 'づ': '즈', 'で': '데', 'ど': '도',
    'な': '나', 'に': '니', 'ぬ': '누', 'ね': '네', 'の': '노',
    'は': '하', 'ひ': '히', 'ふ': '후', 'へ': '헤', 'ほ': '호',
    'ば': '바', 'び': '비', 'ぶ': '부', 'べ': '베', 'ぼ': '보',
    'ぱ': '파', 'ぴ': '피', 'ぷ': '푸', 'ぺ': '페', 'ぽ': '포',
    'ま': '마', 'み': '미', 'む': '무', 'め': '메', 'も': '모',
    'や': '야', 'ゆ': '유', 'よ': '요',
    'ら': '라', 'り': '리', 'る': '루', 'れ': '레', 'ろ': '로',
    'きん': '킨', 'しん': '신', 'ちん': '친',
    'わ': '와', 'を': '오', 'ん': '은',
  };

  static const Map<String, String> _sokuonDouble = {
    '카': '까', '키': '끼', '쿠': '꾸', '케': '께',
    '가': '까', '기': '끼', '구': '꾸', '게': '께',
    '사': '싸', '시': '씨', '스': '쓰', '세': '쎄',
    '타': '따', '치': '찌', '츠': '츳', '테': '때',
    '파': '빠', '피': '삐',
  };

  static List<(String from, String to)> get _sortedPhraseReadings {
    final list = List<(String from, String to)>.from(_phraseReadings)
      ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return list;
  }

  /// 1단계: 한자·가타카나 → 히라가나 (미등록 한자는 건너뛰고 계속).
  static String toHiragana(String text) {
    var work = JapaneseSttFixMap.apply(text.trim());
    if (work.isEmpty) return '';

    for (final pair in _sortedPhraseReadings) {
      work = work.replaceAll(pair.$1, pair.$2);
    }

    final buffer = StringBuffer();
    var i = 0;
    while (i < work.length) {
      final ch = work[i];
      if (_punct.hasMatch(ch)) {
        i++;
        continue;
      }

      if (_hiragana.hasMatch(ch)) {
        buffer.write(ch);
        i++;
        continue;
      }

      if (_katakana.hasMatch(ch)) {
        buffer.write(_katakanaToHiraganaChar(ch));
        i++;
        continue;
      }

      if (_kanji.hasMatch(ch)) {
        var matched = false;
        for (final pair in _sortedPhraseReadings) {
          if (work.startsWith(pair.$1, i)) {
            buffer.write(pair.$2);
            i += pair.$1.length;
            matched = true;
            break;
          }
        }
        if (matched) continue;

        final reading = _kanjiReadings[ch];
        if (reading != null) buffer.write(reading);
        i++;
        continue;
      }

      i++;
    }

    return buffer.toString();
  }

  /// 2단계: 히라가나 → 한글.
  static String toHangul(String hiragana) {
    if (hiragana.isEmpty) return '';
    return _kanaStringToHangul(hiragana);
  }

  /// STT 오답 텍스트 → 한글 발음. 변환 불가 시 `null`.
  static String? transliterateOrNull(String text, {String language = 'Japanese'}) {
    if (language != 'Japanese') return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    try {
      final hiragana = toHiragana(trimmed);
      if (hiragana.isEmpty) return null;
      final hangul = toHangul(hiragana);
      if (hangul.isEmpty || _containsInvalidOutput(hangul)) return null;
      return hangul;
    } catch (_) {
      return null;
    }
  }

  static String _katakanaToHiraganaChar(String ch) {
    final code = ch.runes.first;
    if (code >= 0x30A1 && code <= 0x30F6) {
      return String.fromCharCode(code - 0x60);
    }
    if (code == 0x30FC) return 'ー';
    if (code == 0x30F3) return 'ん';
    if (code == 0x30C3) return 'っ';
    return ch;
  }

  static String _kanaStringToHangul(String hiragana) {
    final sortedKeys = _kanaToHangul.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final buffer = StringBuffer();
    var i = 0;
    while (i < hiragana.length) {
      if (hiragana[i] == 'ー') {
        _applyLongVowel(buffer);
        i++;
        continue;
      }

      if (hiragana[i] == 'っ') {
        final next = _readKanaSyllable(hiragana, i + 1, sortedKeys);
        if (next == null) return buffer.toString();
        buffer.write(_sokuonDouble[next.hangul] ?? next.hangul);
        i = next.nextIndex;
        continue;
      }

      final syllable = _readKanaSyllable(hiragana, i, sortedKeys);
      if (syllable == null) return buffer.toString();
      buffer.write(syllable.hangul);
      i = syllable.nextIndex;
    }

    return buffer.toString();
  }

  static void _applyLongVowel(StringBuffer buffer) {
    final text = buffer.toString();
    if (text.isEmpty) return;
    final lastChar = text[text.length - 1];
    const extendable = {'아', '이', '우', '에', '오', '와', '야', '유', '요'};
    if (extendable.contains(lastChar)) buffer.write(lastChar);
  }

  static ({String hangul, int nextIndex})? _readKanaSyllable(
    String text,
    int start,
    List<String> sortedKeys,
  ) {
    if (start >= text.length) return null;
    for (final key in sortedKeys) {
      if (text.startsWith(key, start)) {
        final hangul = _kanaToHangul[key];
        if (hangul == null) return null;
        return (hangul: hangul, nextIndex: start + key.length);
      }
    }
    return null;
  }

  static bool _containsInvalidOutput(String hangul) {
    return RegExp(r'[ぁ-んァ-ン一-龯A-Za-z]').hasMatch(hangul);
  }
}
