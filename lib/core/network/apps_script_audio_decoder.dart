import 'dart:convert';

/// Apps Script ?audio= 프록시 응답 디코더.
/// {"mime":"audio/mp4","data":"base64..."} → raw bytes
class AppsScriptAudioDecoder {
  AppsScriptAudioDecoder._();

  static List<int> decodeBytes(List<int> rawBytes) {
    final decoded = tryDecode(rawBytes);
    return decoded ?? rawBytes;
  }

  static List<int>? tryDecode(List<int> rawBytes) {
    if (rawBytes.isEmpty) return null;
    try {
      final json = jsonDecode(utf8.decode(rawBytes));
      if (json is! Map) return null;
      if (json.containsKey('error')) {
        throw Exception('${json['error']}: ${json['detail'] ?? ''}');
      }
      final data = json['data'];
      if (data is! String || data.isEmpty) return null;
      return base64Decode(data);
    } catch (e) {
      if (e is Exception && e.toString().contains('Audio not found')) rethrow;
      if (e is FormatException) return null;
      if (e is Exception) rethrow;
      return null;
    }
  }
}
