import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/config/audio_playback_url.dart';
import '../datasources/local/audio_cache_datasource.dart';
import '../datasources/local/content_local_datasource.dart';
import '../datasources/remote/content_remote_datasource.dart';
import '../models/content_bundle.dart';

/// 화면(UI)이 의존하는 유일한 데이터 진입점.
/// 원격(시트 JSON)과 로컬(Hive, 오디오 캐시)을 조합한다.
/// 나중에 웹/Firebase로 확장할 때도 이 인터페이스는 그대로 유지한다.
class ContentRepository {
  final ContentRemoteDataSource _remote;
  final ContentLocalDataSource _local;
  final AudioCacheDataSource _audioCache;
  final String _contentUrl;

  ContentRepository({
    required ContentRemoteDataSource remote,
    required ContentLocalDataSource local,
    required AudioCacheDataSource audioCache,
    required String contentUrl,
  })  : _remote = remote,
        _local = local,
        _audioCache = audioCache,
        _contentUrl = contentUrl;

  /// 로컬에 저장된 콘텐츠. 없으면 null (최초 실행).
  Future<ContentBundle?> loadLocal() => _local.load();

  /// 앱에 번들된 샘플 콘텐츠.
  /// CONTENT_URL 없이 개발·데모용으로 실행할 때 사용한다.
  Future<ContentBundle> loadBundledSample() async {
    final raw = await rootBundle.loadString('assets/sample_content.json');
    return ContentBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<DateTime?> lastSyncedAt() => _local.lastSyncedAt();

  /// 원격에서 콘텐츠를 받아 로컬을 통째로 교체한다.
  Future<ContentBundle> sync() async {
    if (_contentUrl.isEmpty) {
      throw StateError(
        'CONTENT_URL이 설정되지 않았습니다. '
        '--dart-define=CONTENT_URL=... 으로 빌드하세요.',
      );
    }
    final bundle = await _remote.fetch(_contentUrl);
    if (bundle.isEmpty) {
      throw Exception('원격 콘텐츠가 비어 있어 로컬 데이터를 유지합니다.');
    }
    await _local.save(bundle);
    return bundle;
  }

  /// 재생용 오디오 소스 결정: 캐시 파일 경로 우선, 없으면 내려받고, 실패하면 null.
  Future<String?> localAudioPath(String url) => _audioCache.ensureCached(url);

  /// 모든 오디오를 미리 내려받는다 (설정 화면의 "전체 다운로드").
  /// [onProgress]는 (완료 수, 전체 수)를 전달한다.
  Future<int> prefetchAllAudio(
    ContentBundle bundle, {
    void Function(int done, int total)? onProgress,
  }) async {
    final urls = bundle.sentences
        .map((s) => AudioPlaybackUrl.resolve(s.audioUrl))
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();
    var done = 0;
    var succeeded = 0;
    for (final url in urls) {
      final path = await _audioCache.ensureCached(url);
      if (path != null) succeeded++;
      done++;
      onProgress?.call(done, urls.length);
    }
    return succeeded;
  }

  Future<int> audioCacheSizeBytes() => _audioCache.cacheSizeBytes();

  Future<void> clearAudioCache() => _audioCache.clear();
}
