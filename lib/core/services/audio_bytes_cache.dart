import 'dart:convert';
import 'dart:typed_data';

import '../network/apps_script_audio_decoder.dart';
import '../network/apps_script_fetch.dart';

class CachedAudioBytes {
  final Uint8List bytes;
  final String contentType;

  const CachedAudioBytes({
    required this.bytes,
    required this.contentType,
  });
}

/// 디코딩된 오디오 바이트 메모리 캐시 (웹·모바일 공통).
/// Apps Script 프록시(base64 JSON) 응답은 매 요청 3~8초 걸릴 수 있어
/// 한 번 받은 URL은 세션 동안 재사용한다.
class AudioBytesCache {
  AudioBytesCache._();

  static final AudioBytesCache instance = AudioBytesCache._();

  static const int _maxEntries = 80;

  final AppsScriptFetch _fetch = AppsScriptFetch();
  final Map<String, CachedAudioBytes> _cache = {};
  final Map<String, Future<CachedAudioBytes>> _inFlight = {};

  bool contains(String url) => _cache.containsKey(url);

  /// 이미 캐시됐거나 다운로드 중이면 true.
  bool isWarm(String url) => contains(url) || _inFlight.containsKey(url);

  Future<CachedAudioBytes> getOrFetch(String url) {
    final hit = _cache[url];
    if (hit != null) return Future.value(hit);

    final pending = _inFlight[url];
    if (pending != null) return pending;

    final future = _download(url).then((entry) {
      _put(url, entry);
      _inFlight.remove(url);
      return entry;
    }).catchError((Object e, StackTrace st) {
      _inFlight.remove(url);
      Error.throwWithStackTrace(e, st);
    });

    _inFlight[url] = future;
    return future;
  }

  /// 재생 전 미리 받아 둔다. 실패해도 조용히 무시.
  void prefetch(String url) {
    if (url.isEmpty || isWarm(url)) return;
    getOrFetch(url).ignore();
  }

  Future<CachedAudioBytes> _download(String url) async {
    final response = await _fetch.getBytes(url);
    final raw = response.data ?? const <int>[];
    var contentType = 'audio/mpeg';
    try {
      final json = jsonDecode(utf8.decode(raw));
      if (json is Map && json['mime'] is String) {
        contentType = (json['mime'] as String).split(';').first.trim();
      }
    } catch (_) {
      final header = response.headers.value('content-type');
      if (header != null && header.isNotEmpty) {
        contentType = header.split(';').first.trim();
      }
    }
    final bytes = Uint8List.fromList(AppsScriptAudioDecoder.decodeBytes(raw));
    return CachedAudioBytes(bytes: bytes, contentType: contentType);
  }

  void _put(String url, CachedAudioBytes entry) {
    if (_cache.length >= _maxEntries && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = entry;
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
