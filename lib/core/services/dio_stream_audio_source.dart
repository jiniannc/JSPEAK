// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';

import '../network/apps_script_audio_decoder.dart';
import '../network/apps_script_fetch.dart';

/// 원격 오디오 URL을 바이트로 받아 재생한다.
/// Apps Script 프록시(base64 JSON)와 일반 URL 모두 지원한다.
class DioStreamAudioSource extends StreamAudioSource {
  final AppsScriptFetch _fetch;
  final String url;

  DioStreamAudioSource(
    this.url, {
    AppsScriptFetch? fetch,
    super.tag,
  }) : _fetch = fetch ?? AppsScriptFetch();

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (start != null || end != null) {
      throw UnsupportedError('Range requests are not supported for remote audio.');
    }

    final response = await _fetch.getBytes(url);
    final rawBytes = response.data ?? const <int>[];
    final bytes = AppsScriptAudioDecoder.decodeBytes(rawBytes);
    final contentType = _contentTypeFrom(response, rawBytes);

    return StreamAudioResponse(
      rangeRequestsSupported: false,
      sourceLength: bytes.length,
      contentLength: bytes.length,
      offset: 0,
      contentType: contentType,
      stream: Stream<List<int>>.value(bytes),
    );
  }

  String _contentTypeFrom(Response<List<int>> response, List<int> rawBytes) {
    try {
      final json = jsonDecode(utf8.decode(rawBytes));
      if (json is Map && json['mime'] is String) {
        return (json['mime'] as String).split(';').first.trim();
      }
    } catch (_) {}
    final raw = response.headers.value('content-type');
    if (raw == null || raw.isEmpty) return 'audio/mpeg';
    return raw.split(';').first.trim();
  }
}
