import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/content_bundle.dart';

/// 콘텐츠를 Hive에 JSON 문자열 하나로 저장한다.
/// TypeAdapter/코드생성 없이 유지보수가 쉽고, 웹(IndexedDB 기반 Hive)에서도 그대로 동작한다.
class ContentLocalDataSource {
  static const _boxName = 'jspeak_content';
  static const _contentKey = 'content_json';
  static const _syncedAtKey = 'last_synced_at';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<ContentBundle?> load() async {
    final box = await _openBox();
    final raw = box.get(_contentKey);
    if (raw == null) return null;
    try {
      return ContentBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 저장 포맷이 깨졌으면 없는 것으로 취급하고 다음 동기화에서 덮어쓴다.
      return null;
    }
  }

  Future<void> save(ContentBundle bundle) async {
    final box = await _openBox();
    await box.put(_contentKey, jsonEncode(bundle.toJson()));
    await box.put(_syncedAtKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> lastSyncedAt() async {
    final box = await _openBox();
    final raw = box.get(_syncedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
