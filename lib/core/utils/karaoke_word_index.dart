import 'word_compare.dart';

/// 오디오 재생 진행률로 가라오케 하이라이트 단어 인덱스를 계산한다.
class KaraokeWordIndex {
  KaraokeWordIndex._();

  static int? resolve({
    required bool isActive,
    required Duration position,
    required Duration duration,
    required String sentence,
    required String language,
  }) {
    if (!isActive || duration.inMilliseconds <= 0) return null;

    final words = WordCompare.splitTokens(sentence, language: language);
    if (words.isEmpty) return null;

    final maxMs = duration.inMilliseconds;
    final currentMs = position.inMilliseconds.clamp(0, maxMs);
    if (currentMs <= 0) return 0;

    final progress = currentMs / maxMs;
    return (progress * words.length).floor().clamp(0, words.length - 1);
  }

  /// TTS 진행 오프셋으로 현재 토큰 인덱스를 계산한다.
  static int? resolveFromOffset({
    required String sentence,
    required String language,
    required int startOffset,
  }) {
    if (sentence.isEmpty) return null;
    final tokens = WordCompare.splitTokens(sentence, language: language);
    if (tokens.isEmpty) return null;

    final offset = startOffset.clamp(0, sentence.length);

    if (WordCompare.isCjkLanguage(language) && !sentence.contains(' ')) {
      var i = 0;
      var tokenIdx = 0;
      while (i < sentence.length) {
        final cu = sentence.codeUnitAt(i);
        final len =
            (cu >= 0xD800 && cu <= 0xDBFF && i + 1 < sentence.length) ? 2 : 1;
        final end = i + len;
        if (offset < end) {
          return tokenIdx.clamp(0, tokens.length - 1);
        }
        i = end;
        tokenIdx++;
      }
      return tokens.length - 1;
    }

    var i = 0;
    var wordIdx = 0;
    while (i < sentence.length) {
      while (i < sentence.length && sentence[i] == ' ') {
        i++;
      }
      if (i >= sentence.length) break;
      final start = i;
      while (i < sentence.length && sentence[i] != ' ') {
        i++;
      }
      if (offset <= start || offset < i) {
        return wordIdx.clamp(0, tokens.length - 1);
      }
      wordIdx++;
    }
    return (wordIdx - 1).clamp(0, tokens.length - 1);
  }
}
