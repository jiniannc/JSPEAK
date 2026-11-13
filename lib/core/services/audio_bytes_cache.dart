import 'dart:async';
import 'dart:collection';
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
///
/// 모든 오디오 네트워크 요청이 이 클래스를 거친다. 백그라운드 요청은
/// [maxBackgroundConcurrency]개로 제한하고, 사용자가 누른 재생([priority])은
/// 대기열을 건너뛰어 즉시 시작한다.
class AudioBytesCache {
  AudioBytesCache._();

  static final AudioBytesCache instance = AudioBytesCache._();

  static const int _maxEntries = 80;
  static const int maxBackgroundConcurrency = 3;

  /// 이보다 작은 응답은 오디오가 아닌 오류 페이지로 본다.
  static const int _minAudioBytes = 512;

  final AppsScriptFetch _fetch = AppsScriptFetch();
  final Map<String, CachedAudioBytes> _cache = {};
  final Map<String, Future<CachedAudioBytes>> _inFlight = {};
  final Queue<_PendingFetch> _queue = Queue();
  int _activeBackground = 0;

  bool contains(String url) => _cache.containsKey(url);

  /// 이미 캐시됐거나 다운로드 중이면 true.
  bool isWarm(String url) => contains(url) || _inFlight.containsKey(url);

  Future<CachedAudioBytes> getOrFetch(String url, {bool priority = false}) {
    final hit = _cache[url];
    if (hit != null) return Future.value(hit);

    final pending = _inFlight[url];
    if (pending != null) {
      if (priority) _promote(url);
      return pending;
    }

    final completer = Completer<CachedAudioBytes>();
    _inFlight[url] = completer.future;
    final job = _PendingFetch(url, completer);
    if (priority) {
      _start(job, background: false);
    } else {
      _queue.add(job);
      _pump();
    }
    return completer.future;
  }

  /// 재생 전 미리 받아 둔다. 실패해도 조용히 무시.
  void prefetch(String url) {
    if (url.isEmpty || isWarm(url)) return;
    getOrFetch(url).ignore();
  }

  void _promote(String url) {
    _PendingFetch? job;
    for (final j in _queue) {
      if (j.url == url) {
        job = j;
        break;
      }
    }
    if (job == null) return;
    _queue.remove(job);
    _start(job, background: false);
  }

  void _pump() {
    while (_activeBackground < maxBackgroundConcurrency && _queue.isNotEmpty) {
      _start(_queue.removeFirst(), background: true);
    }
  }

  void _start(_PendingFetch job, {required bool background}) {
    if (background) _activeBackground++;
    _download(job.url).then((entry) {
      _put(job.url, entry);
      job.completer.complete(entry);
    }, onError: (Object e, StackTrace st) {
      job.completer.completeError(e, st);
    }).whenComplete(() {
      _inFlight.remove(job.url);
      if (background) _activeBackground--;
      _pump();
    });
  }

  Future<CachedAudioBytes> _download(String url) async {
    final response = await _fetch.getBytes(url);
    final raw = response.data ?? const <int>[];
    var contentType = 'audio/mpeg';
    var isProxyJson = false;
    try {
      final json = jsonDecode(utf8.decode(raw));
      if (json is Map) {
        isProxyJson = true;
        if (json['mime'] is String) {
          contentType = (json['mime'] as String).split(';').first.trim();
        }
      }
    } catch (_) {
      final header = response.headers.value('content-type');
      if (header != null && header.isNotEmpty) {
        contentType = header.split(';').first.trim();
      }
    }

    final List<int> decoded;
    if (AppsScriptFetch.isWebAppUrl(url)) {
      // 프록시는 항상 base64 JSON. HTML(할당량·로그인 페이지) 등은 오디오로 저장하지 않는다.
      final proxied = AppsScriptAudioDecoder.tryDecode(raw);
      if (proxied == null) {
        throw StateError(
          isProxyJson
              ? '오디오 프록시 응답에 data가 없습니다: $url'
              : '오디오 프록시가 JSON이 아닌 응답을 반환했습니다: $url',
        );
      }
      decoded = proxied;
    } else {
      if (contentType.startsWith('text/')) {
        throw StateError('오디오 대신 텍스트 응답을 받았습니다: $url');
      }
      decoded = raw;
    }

    if (decoded.length < _minAudioBytes) {
      throw StateError('오디오 크기가 너무 작습니다 (${decoded.length}B): $url');
    }
    return CachedAudioBytes(
      bytes: Uint8List.fromList(decoded),
      contentType: contentType,
    );
  }

  void _put(String url, CachedAudioBytes entry) {
    if (_cache.length >= _maxEntries && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = entry;
  }

  /// 디스크에 저장한 뒤 메모리에서 내려 전체 다운로드 시 메모리를 아낀다.
  void evict(String url) => _cache.remove(url);

  void clear() {
    _cache.clear();
  }
}

class _PendingFetch {
  final String url;
  final Completer<CachedAudioBytes> completer;

  _PendingFetch(this.url, this.completer);
}
