import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/audio_playback_url.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/services/audio_bytes_cache.dart';

/// 오디오 파일을 기기에 내려받아 오프라인 재생을 지원한다.
/// 캐시 키는 URL 해시라서, 시트에서 오디오 URL을 바꾸면 자연스럽게 새로 받는다.
/// 웹에서는 파일 시스템이 없으므로 캐시 없이 스트리밍으로 폴백한다.
class AudioCacheDataSource {
  final AudioBytesCache _bytes;

  AudioCacheDataSource([AudioBytesCache? bytes])
      : _bytes = bytes ?? AudioBytesCache.instance;

  /// 같은 파일을 동시에 여러 곳(재생·카테고리 프리로드·전체 다운로드)에서 써도 한 번만 저장.
  static final Map<String, Future<String>> _writing = {};
  static int _tmpSeq = 0;

  Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}audio_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileNameFor(String url) =>
      '${md5.convert(utf8.encode(AudioPlaybackUrl.cacheKey(url)))}.audio';

  /// URL 전체 해시를 쓰던 이전 버전의 파일 이름.
  String _legacyFileNameFor(String url) =>
      '${md5.convert(utf8.encode(url))}.audio';

  Future<String> _pathFor(String url) async {
    final dir = await _cacheDir();
    return '${dir.path}${Platform.pathSeparator}${_fileNameFor(url)}';
  }

  /// 이전 키로 저장된 파일이 있으면 새 키 이름으로 옮긴다.
  Future<void> _migrateLegacy(String url, File target) async {
    if (await target.exists()) return;
    final legacy = File(
      '${target.parent.path}${Platform.pathSeparator}${_legacyFileNameFor(url)}',
    );
    if (legacy.path == target.path || !await legacy.exists()) return;
    try {
      await legacy.rename(target.path);
    } catch (_) {}
  }

  /// 캐시된 파일 경로. 없으면 null.
  Future<String?> cachedPath(String url) async {
    if (kIsWeb || url.isEmpty) return null;
    final file = File(await _pathFor(url));
    await _migrateLegacy(url, file);
    if (!await file.exists()) return null;
    if (await file.length() == 0) {
      await _deleteQuietly(file);
      return null;
    }
    return file.path;
  }

  /// URL을 내려받아 캐시하고 로컬 경로를 반환. 웹이면 null.
  /// [priority]면 백그라운드 다운로드 대기열을 건너뛴다.
  Future<String?> download(String url, {bool priority = false}) async {
    if (kIsWeb || url.isEmpty) return null;
    final writing = _writing[url];
    if (writing != null) {
      if (priority) _bytes.getOrFetch(url, priority: true).ignore();
      return writing;
    }

    final future = _downloadAndWrite(url, priority: priority);
    _writing[url] = future;
    try {
      return await future;
    } finally {
      _writing.remove(url);
    }
  }

  Future<String> _downloadAndWrite(String url, {required bool priority}) async {
    final path = await _pathFor(url);
    final existing = File(path);
    if (await existing.exists() && await existing.length() > 0) return path;

    final audio = await _bytes.getOrFetch(url, priority: priority);
    final tmp = File('$path.${DateTime.now().microsecondsSinceEpoch}_${_tmpSeq++}.tmp');
    try {
      await tmp.writeAsBytes(audio.bytes, flush: true);
      await tmp.rename(path);
    } catch (_) {
      await _deleteQuietly(tmp);
      rethrow;
    }
    if (!priority) _bytes.evict(url);
    return path;
  }

  /// 캐시가 있으면 경로 반환, 없으면 내려받아서 반환. 실패/웹이면 null.
  Future<String?> ensureCached(String url, {bool priority = false}) async {
    final existing = await cachedPath(url);
    if (existing != null) return existing;
    try {
      return await download(url, priority: priority);
    } catch (e, st) {
      AppLog.debug('audio_cache', '오디오 캐시 실패: $url', e, st);
      return null;
    }
  }

  /// 재생에 실패한(손상된) 캐시 파일 삭제 — 다음 시도에서 새로 받는다.
  Future<void> evict(String url) async {
    if (kIsWeb || url.isEmpty) return;
    await _deleteQuietly(File(await _pathFor(url)));
    _bytes.evict(url);
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<int> cacheSizeBytes() async {
    if (kIsWeb) return 0;
    final dir = await _cacheDir();
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clear() async {
    if (kIsWeb) return;
    final dir = await _cacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
