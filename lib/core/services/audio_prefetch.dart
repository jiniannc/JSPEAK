import '../config/audio_playback_url.dart';
import '../../data/models/sentence.dart';
import 'audio_bytes_cache.dart';

/// 화면에 보이는 문장·다음 문장 오디오를 미리 받아 재생 지연을 줄인다.
class AudioPrefetch {
  AudioPrefetch._();

  static final AudioBytesCache _cache = AudioBytesCache.instance;

  static void sentence(Sentence sentence) {
    final url = AudioPlaybackUrl.resolve(sentence.audioUrl);
    if (url.isNotEmpty) _cache.prefetch(url);
  }

  static void sentences(Iterable<Sentence> list, {int limit = 6}) {
    var count = 0;
    for (final s in list) {
      if (count >= limit) break;
      if (s.audioUrl.isEmpty) continue;
      sentence(s);
      count++;
    }
  }

  /// [index] 주변 문장을 프리페치 (학습 휠·리스트).
  static void around(
    List<Sentence> sentences,
    int index, {
    int before = 1,
    int after = 2,
  }) {
    if (sentences.isEmpty) return;
    final start = (index - before).clamp(0, sentences.length - 1);
    final end = (index + after).clamp(0, sentences.length - 1);
    for (var i = start; i <= end; i++) {
      sentence(sentences[i]);
    }
  }
}
