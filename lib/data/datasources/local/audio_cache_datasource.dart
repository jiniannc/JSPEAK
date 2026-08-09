import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../../../core/network/apps_script_audio_decoder.dart';
import '../../../core/network/apps_script_fetch.dart';

/// 오디오 파일을 기기에 내려받아 오프라인 재생을 지원한다.
/// 캐시 키는 URL 해시라서, 시트에서 오디오 URL을 바꾸면 자연스럽게 새로 받는다.
/// 웹에서는 파일 시스템이 없으므로 캐시 없이 스트리밍으로 폴백한다.
class AudioCacheDataSource {
  final Dio _dio;

  AudioCacheDataSource([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 2),
              followRedirects: true,
              maxRedirects: 5,
            ));

  Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}audio_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileNameFor(String url) =>
      '${md5.convert(utf8.encode(url))}.audio';

  /// 캐시된 파일 경로. 없으면 null.
  Future<String?> cachedPath(String url) async {
    if (kIsWeb || url.isEmpty) return null;
    final dir = await _cacheDir();
    final file = File('${dir.path}${Platform.pathSeparator}${_fileNameFor(url)}');
    return await file.exists() ? file.path : null;
  }

  /// URL을 내려받아 캐시하고 로컬 경로를 반환. 웹이면 null.
  Future<String?> download(String url) async {
    if (kIsWeb || url.isEmpty) return null;
    final dir = await _cacheDir();
    final path = '${dir.path}${Platform.pathSeparator}${_fileNameFor(url)}';
    final tmpPath = '$path.tmp';

    if (AppsScriptFetch.isWebAppUrl(url)) {
      final fetch = AppsScriptFetch();
      final response = await fetch.getBytes(url);
      final bytes = AppsScriptAudioDecoder.decodeBytes(response.data ?? const []);
      await File(tmpPath).writeAsBytes(bytes, flush: true);
    } else {
      await _dio.download(url, tmpPath);
    }

    final tmp = File(tmpPath);
    await tmp.rename(path);
    return path;
  }

  /// 캐시가 있으면 경로 반환, 없으면 내려받아서 반환. 실패/웹이면 null.
  Future<String?> ensureCached(String url) async {
    final existing = await cachedPath(url);
    if (existing != null) return existing;
    try {
      return await download(url);
    } catch (_) {
      return null;
    }
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
