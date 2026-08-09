import 'package:hive_flutter/hive_flutter.dart';

/// 사용자 즐겨찾기 문장 ID (최근 추가가 앞).
class FavoriteSentencesLocalDataSource {
  static const _boxName = 'jspeak_favorites';
  static const _key = 'sentence_ids';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<List<String>> load() async {
    final box = await _openBox();
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) return const [];
    return raw.split('\n').where((e) => e.isNotEmpty).toList();
  }

  Future<List<String>> toggle(String sentenceId) async {
    final box = await _openBox();
    final current = await load();
    final next = List<String>.from(current);
    if (next.contains(sentenceId)) {
      next.remove(sentenceId);
    } else {
      next.insert(0, sentenceId);
    }
    await box.put(_key, next.join('\n'));
    return next;
  }

  Future<bool> isFavorite(String sentenceId) async {
    final ids = await load();
    return ids.contains(sentenceId);
  }
}
