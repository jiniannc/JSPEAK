import 'package:lpinyin/lpinyin.dart';

/// STT 중국어 한자 → 성조(Tone mark) 병음 변환.
class HanziToPinyinConverter {
  HanziToPinyinConverter._();

  static final RegExp _hanzi = RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF]');

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
}
