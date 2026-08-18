import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/utils/chapter_asset_path.dart';

/// 스프레드시트 한 행에 해당하는 문장.
class Sentence {
  final String id;
  final String language;
  final int chapterNo;
  final String category;
  final String chapterImage;
  final String chapterHook;
  final String sentence;
  final String pronunciation;
  final String korean;
  final String audioUrl;

  /// 별 개수 (시트의 popular 열).
  final int stars;

  /// 필수 문장 여부 (시트 important 열 — Yes/No, true/false, 체크박스).
  final bool important;

  const Sentence({
    required this.id,
    required this.language,
    this.chapterNo = 1,
    required this.category,
    this.chapterImage = '',
    this.chapterHook = '',
    required this.sentence,
    required this.pronunciation,
    required this.korean,
    required this.audioUrl,
    required this.stars,
    required this.important,
  });

  /// 행 순서가 바뀌어도 변하지 않는 내용 기반 ID.
  /// 즐겨찾기·오디오 캐시 등의 키로 사용한다.
  static String stableId(String language, String category, String sentence) {
    return md5.convert(utf8.encode('$language|$category|$sentence')).toString();
  }

  factory Sentence.fromJson(Map<String, dynamic> json) {
    final language = (json['language'] ?? '') as String;
    final category = (json['category'] ?? '') as String;
    final text = (json['sentence'] ?? '') as String;
    return Sentence(
      id: stableId(language, category, text),
      language: language,
      chapterNo: _parseChapterNo(json['chapter_no']),
      category: category,
      chapterImage: resolveChapterAssetPath(
        (json['chapter_image'] ?? '') as String,
      ),
      chapterHook: (json['chapter_hook'] ?? '') as String,
      sentence: text,
      pronunciation: (json['pronunciation'] ?? '') as String,
      korean: (json['korean'] ?? '') as String,
      audioUrl: resolveAudioUrl((json['audio'] ?? '') as String),
      stars: _parseInt(json['popular']),
      important: _parseImportant(json['important']),
    );
  }

  static bool _parseImportant(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'yes' ||
        normalized == 'true' ||
        normalized == '1' ||
        normalized == 'y';
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'chapter_no': chapterNo,
        'category': category,
        'chapter_image': chapterImage,
        if (chapterHook.isNotEmpty) 'chapter_hook': chapterHook,
        'sentence': sentence,
        'pronunciation': pronunciation,
        'korean': korean,
        'audio': audioUrl,
        'popular': stars,
        'important': important ? 'Yes' : 'No',
      };

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  static int _parseChapterNo(Object? value) {
    final parsed = _parseInt(value);
    return parsed <= 0 ? 1 : parsed;
  }

  /// 시트 audio 값(파일 ID 또는 URL)을 앱이 재생할 수 있는 URL로 변환한다.
  static String resolveAudioUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final driveId = extractDriveFileId(value);
      if (driveId != null) return _driveDownloadUrl(driveId);
      return value;
    }

    return _driveDownloadUrl(value);
  }

  static String _driveDownloadUrl(String fileId) =>
      'https://drive.usercontent.google.com/download?id=$fileId&export=download';

  static String? extractDriveFileId(String url) {
    final fileMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (fileMatch != null) return fileMatch.group(1);
    final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (idMatch != null) return idMatch.group(1);
    return null;
  }
}
