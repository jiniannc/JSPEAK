import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Hive 기반 칭호 뱃지 획득 일자 저장.
class TitleBadgeLocalDataSource {
  static const _boxName = 'jspeak_title_badges';
  static const _unlocksKey = 'title_badge_unlocks';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<Map<String, DateTime>> loadUnlockDates() async {
    final box = await _openBox();
    final raw = box.get(_unlocksKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final parsed = DateTime.tryParse(entry.value.toString());
        if (parsed != null) result[entry.key] = parsed;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveUnlockDates(Map<String, DateTime> dates) async {
    final box = await _openBox();
    final encoded = jsonEncode(
      dates.map((key, value) => MapEntry(key, value.toIso8601String())),
    );
    await box.put(_unlocksKey, encoded);
  }
}
