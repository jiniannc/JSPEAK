import '../../data/models/sentence.dart';
import 'app_config.dart';

/// 재생·캐시 시 사용할 오디오 URL을 결정한다.
/// Drive 파일은 브라우저 CORS/CORP 때문에 직접 재생이 안 되므로
/// CONTENT_URL(Apps Script) 프록시를 경유한다.
class AudioPlaybackUrl {
  AudioPlaybackUrl._();

  static String resolve(String raw, {String? proxyBase}) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    if (_isScriptAudioProxy(value)) return value;

    final driveId = _driveFileId(value);
    final base = proxyBase ?? AppConfig.normalizedContentUrl;
    if (driveId != null && base.isNotEmpty) {
      return _proxyUrl(base, driveId);
    }

    return Sentence.resolveAudioUrl(value);
  }

  static String? _driveFileId(String value) {
    if (!value.startsWith('http')) {
      if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) return value;
      return null;
    }
    return Sentence.extractDriveFileId(value);
  }

  static bool _isScriptAudioProxy(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.host.contains('script.google.com')) return false;
    if (uri.queryParameters.containsKey('audio')) return true;
    final audioIndex = uri.pathSegments.indexOf('audio');
    return audioIndex >= 0 && audioIndex < uri.pathSegments.length - 1;
  }

  static String _proxyUrl(String base, String fileId) {
    final uri = Uri.parse(base);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'audio': fileId,
    }).toString();
  }
}
