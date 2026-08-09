import 'package:hive_flutter/hive_flutter.dart';

import 'favorite_sentences_local_datasource.dart';

/// 기내사전 통합 즐겨찾기 — `s:<sentenceId>` · `w:<language>|<term>`.
class DictionaryFavoritesLocalDataSource {
  static const _boxName = 'jspeak_dictionary_favorites';
  static const _key = 'ordered_keys';

  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<List<String>> load() async {
    final box = await _openBox();
    final raw = box.get(_key);
    if (raw != null && raw.isNotEmpty) {
      return raw.split('\n').where((e) => e.isNotEmpty).toList();
    }

    // 레거시 문장 즐겨찾기 마이그레이션
    final legacy = FavoriteSentencesLocalDataSource();
    final sentenceIds = await legacy.load();
    if (sentenceIds.isEmpty) return const [];

    final migrated = sentenceIds.map((id) => 's:$id').toList();
    await box.put(_key, migrated.join('\n'));
    return migrated;
  }

  Future<List<String>> save(List<String> keys) async {
    final box = await _openBox();
    await box.put(_key, keys.join('\n'));
    return keys;
  }

  Future<List<String>> toggle(String key) async {
    final current = await load();
    final next = List<String>.from(current);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.insert(0, key);
    }
    return save(next);
  }

  Future<bool> contains(String key) async {
    final keys = await load();
    return keys.contains(key);
  }
}
