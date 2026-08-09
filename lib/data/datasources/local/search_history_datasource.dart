import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 최근 검색어 로컬 저장.
class SearchHistoryDataSource {
  static const _boxName = 'jspeak_search_history';
  static const _key = 'recent_queries';
  static const maxItems = 10;

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<List<String>> load() async {
    final box = await _openBox();
    final raw = box.get(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();

    final current = await load();
    final updated = [
      trimmed,
      ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ].take(maxItems).toList();

    final box = await _openBox();
    await box.put(_key, jsonEncode(updated));
    return updated;
  }

  Future<List<String>> remove(String query) async {
    final updated = (await load())
        .where((q) => q.toLowerCase() != query.toLowerCase())
        .toList();
    final box = await _openBox();
    await box.put(_key, jsonEncode(updated));
    return updated;
  }

  Future<void> clear() async {
    final box = await _openBox();
    await box.delete(_key);
  }
}
