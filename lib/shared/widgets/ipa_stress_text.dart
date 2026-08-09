import 'package:flutter/material.dart';

import '../../features/dashboard/dashboard_palette.dart';

/// IPA 발음 기호에서 주강세(ˈ) 음절만 라임색으로, 부강세(ˌ)는 청록으로 표시한다.
///
/// 예) `[ˌsuːvəˈnɪə]` → suː(부강세), nɪə(주강세 'nir'에 해당)
class IpaStressText extends StatelessWidget {
  final String ipa;
  final TextStyle baseStyle;

  const IpaStressText({
    super.key,
    required this.ipa,
    required this.baseStyle,
  });

  static const _primaryStress = 'ˈ';
  static const _secondaryStress = 'ˌ';

  static const Set<String> _vowelChars = {
    'i', 'ɪ', 'e', 'ɛ', 'æ', 'ə', 'ɚ', 'ɜ', 'ɑ', 'ɒ', 'ɔ', 'ʊ', 'u', 'ʌ', 'a', 'o',
  };

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: buildStressSpans(ipa, baseStyle),
      ),
    );
  }

  /// 테스트·재사용을 위해 public.
  static List<TextSpan> buildStressSpans(String raw, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    var i = 0;

    while (i < raw.length) {
      final ch = raw[i];

      if (ch == _primaryStress) {
        spans.add(_stressMarkSpan(ch, baseStyle));
        i++;
        final len = _syllableLength(raw, i);
        if (len > 0) {
          spans.add(_primarySyllableSpan(raw.substring(i, i + len), baseStyle));
          i += len;
        }
        continue;
      }

      if (ch == _secondaryStress) {
        spans.add(_stressMarkSpan(ch, baseStyle));
        i++;
        final len = _syllableLength(raw, i);
        if (len > 0) {
          spans.add(_secondarySyllableSpan(raw.substring(i, i + len), baseStyle));
          i += len;
        }
        continue;
      }

      if (_isDelimiter(ch)) {
        spans.add(TextSpan(text: ch, style: baseStyle));
        i++;
        continue;
      }

      final start = i;
      while (i < raw.length &&
          raw[i] != _primaryStress &&
          raw[i] != _secondaryStress &&
          !_isDelimiter(raw[i])) {
        i++;
      }
      spans.add(_unstressedSpan(raw.substring(start, i), baseStyle));
    }

    return spans;
  }

  /// ˈ/ˌ 바로 뒤 **한 음절** 길이 (onset + nucleus + coda).
  static int _syllableLength(String text, int start) {
    var i = start;
    final len = text.length;
    if (i >= len) return 0;

    while (i < len && _isConsonant(text[i])) {
      i++;
    }

    if (i >= len || !_isVowel(text[i])) {
      return i > start ? i - start : 1;
    }

    i++;
    if (i < len && text[i] == 'ː') i++;

    if (i < len && _isVowel(text[i])) {
      final prevIndex = text[i - 1] == 'ː' ? i - 2 : i - 1;
      if (prevIndex >= start && _isDiphthong(text[prevIndex], text[i])) {
        i++;
      }
    }

    while (i < len && _isConsonant(text[i])) {
      i++;
    }

    return i - start;
  }

  static bool _isVowel(String char) => _vowelChars.contains(char);

  static bool _isConsonant(String char) {
    if (char == 'ː' || char == _primaryStress || char == _secondaryStress) {
      return false;
    }
    return !_isVowel(char) && char.trim().isNotEmpty && !_isDelimiter(char);
  }

  static bool _isDelimiter(String char) =>
      char == ' ' || char == '/' || char == '[' || char == ']' || char == ',';

  static bool _isDiphthong(String first, String second) {
    const pairs = {
      'aɪ', 'aʊ', 'eɪ', 'oʊ', 'ɔɪ', 'ɪə', 'ʊə', 'eə', 'əʊ',
    };
    return pairs.contains('$first$second');
  }

  static TextSpan _stressMarkSpan(String mark, TextStyle base) => TextSpan(
        text: mark,
        style: base.copyWith(
          color: DashboardPalette.textMuted,
          fontWeight: FontWeight.w600,
        ),
      );

  static TextSpan _primarySyllableSpan(String text, TextStyle base) => TextSpan(
        text: text,
        style: base.copyWith(
          color: DashboardPalette.lime,
          fontWeight: FontWeight.w800,
        ),
      );

  static TextSpan _secondarySyllableSpan(String text, TextStyle base) => TextSpan(
        text: text,
        style: base.copyWith(
          color: DashboardPalette.teal,
          fontWeight: FontWeight.w700,
        ),
      );

  static TextSpan _unstressedSpan(String text, TextStyle base) => TextSpan(
        text: text,
        style: base.copyWith(
          color: DashboardPalette.teal.withValues(alpha: 0.55),
          fontWeight: FontWeight.w500,
        ),
      );
}
