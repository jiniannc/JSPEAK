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
}
