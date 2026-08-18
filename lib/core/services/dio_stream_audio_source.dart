// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'audio_bytes_cache.dart';

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
    if (start != null || end != null) {
      throw UnsupportedError('Range requests are not supported for remote audio.');
    }

    final cached = await _cache.getOrFetch(url);

    return StreamAudioResponse(
      rangeRequestsSupported: false,
      sourceLength: cached.bytes.length,
      contentLength: cached.bytes.length,
      offset: 0,
      contentType: cached.contentType,
      stream: Stream<List<int>>.value(cached.bytes),
    );
  }
}
