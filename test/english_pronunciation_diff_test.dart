import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/english_pronunciation_tokens.dart';
import 'package:jspeak/core/utils/word_token_alignment.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('EnglishPronunciationTokens', () {
    test('Q R 분리 토큰을 QR로 병합', () {
      expect(
        EnglishPronunciationTokens.mergeInText('May I see your Q R code'),
        'May I see your QR code',
      );
    });

    test('queue를 QR과 동치로 인식', () {
      expect(EnglishPronunciationTokens.areEquivalent('queue', 'QR'), isTrue);
    });

    test('인식 문장 — 첫 글자 대문자 + 원문 ? 미러링', () {
      expect(
        EnglishPronunciationTokens.formatSpokenSentence(
          'may I help you with your baggage',
          'May I help you with your luggage?',
        ),
        'May I help you with your baggage?',
      );
    });
  });

  group('formatEnglishSpokenTokensForDisplay', () {
    test('첫 토큰 capitalize + 마지막 spoken 토큰에 ?', () {
      const target = 'May I help you with your luggage?';
      const spoken = 'may I help you with your baggage';
      final raw = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'English',
      );
      final display = formatEnglishSpokenTokensForDisplay(raw, target);

      expect(
        display.whereType<PronunciationInlineDiffMatch>().first.word,
        'May',
      );
      expect(
        display.whereType<PronunciationInlineDiffCorrection>().single.spoken,
        'baggage?',
      );
    });
  });

  group('English sentence-level diff UI', () {
    const target = 'May I see your QR code';
    const spoken = 'May I have your Q R code';

    test('오차가 있으면 문장 전체 red/green 클러스터 1개', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'English',
      );

      expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isNotEmpty);
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().map((t) => t.word),
        contains('May'),
      );
    });

    test('baggage/luggage — match 단어와 correction 분리', () {
      const target = 'May I help you with your luggage?';
      const spoken = 'may I help you with your baggage';
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'English',
      );

      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().length,
        greaterThanOrEqualTo(5),
      );
      expect(
        tokens.whereType<PronunciationInlineDiffCorrection>().single.spoken,
        'baggage',
      );

      final display = formatEnglishSpokenTokensForDisplay(tokens, target);
      expect(display.first, isA<PronunciationInlineDiffMatch>());
      expect(
        (display.first as PronunciationInlineDiffMatch).word,
        'May',
      );
      expect(
        display.whereType<PronunciationInlineDiffCorrection>().single.spoken,
        'baggage?',
      );
    });

    test('100점 전부 match — 첫 글자 대문자 + . 미러링', () {
      const target = 'Please fasten your seat belt.';
      const spoken = 'please fasten your seat belt';
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'English',
      );

      expect(tokens.every((t) => t is PronunciationInlineDiffMatch), isTrue);

      final display = formatEnglishSpokenTokensForDisplay(tokens, target);
      expect(
        (display.first as PronunciationInlineDiffMatch).word,
        'Please',
      );
      expect(
        (display.last as PronunciationInlineDiffMatch).word,
        'belt.',
      );
    });

    test('Q R 병합 시 QR 매칭으로 점수 상승', () {
      final withoutMerge = WordTokenAligner.accuracyPercent(
        targetText: target,
        spokenText: 'May I see your code',
        language: 'English',
      );
      final withQr = WordTokenAligner.accuracyPercent(
        targetText: target,
        spokenText: 'May I see your Q R code',
        language: 'English',
      );
      expect(withQr, greaterThan(withoutMerge));
    });
  });
}
