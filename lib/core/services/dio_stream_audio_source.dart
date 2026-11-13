// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

import 'audio_bytes_cache.dart';

/// just_audio [StreamAudioSource.request] 규약: [start] 포함, [end] 미포함.
({int from, int to, Uint8List slice}) resolveStreamAudioSlice(
  Uint8List bytes,
  int? start,
  int? end,
) {
  final length = bytes.length;
  if (length == 0) {
    return (from: 0, to: 0, slice: Uint8List(0));
  }
  final from = (start ?? 0).clamp(0, length);
  final to = (end ?? length).clamp(from, length);
  return (from: from, to: to, slice: bytes.sublist(from, to));
}

/// 원격 오디오 URL을 바이트로 받아 재생한다.
/// Apps Script 프록시(base64 JSON)와 일반 URL 모두 지원한다.
class DioStreamAudioSource extends StreamAudioSource {
  final String url;
  final AudioBytesCache _cache;

  DioStreamAudioSource(
    this.url, {
    AudioBytesCache? cache,
    super.tag,
  }) : _cache = cache ?? AudioBytesCache.instance;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final cached = await _cache.getOrFetch(url);
    final bytes = cached.bytes;
    final length = bytes.length;
    final range = resolveStreamAudioSlice(bytes, start, end);

    return StreamAudioResponse(
      // Android ExoPlayer는 메타데이터 확인용 range 요청을 보낸다.
      rangeRequestsSupported: true,
      sourceLength: length,
      contentLength: range.slice.length,
      offset: range.from,
      contentType: cached.contentType,
      stream: Stream<List<int>>.value(range.slice),
    );
  }
}
