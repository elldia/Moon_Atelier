import 'package:hive_flutter/hive_flutter.dart';

import '../models/highlight.dart';

/// Persists per-book saved text highlights ("자주 찾는 글귀") in their own
/// Hive box.
class HighlightStore {
  static const _boxName = 'highlights';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError('HighlightStore.init() must be awaited before use.');
    }
    return box;
  }

  static List<Highlight> forBook(String bookId) {
    final items = _b.keys
        .cast<String>()
        .where((key) => (_b.get(key) as Map)['bookId'] == bookId)
        .map((key) => Highlight.fromMap(key, _b.get(key) as Map))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static List<Highlight> loadAll() => _b.keys
      .cast<String>()
      .map((key) => Highlight.fromMap(key, _b.get(key) as Map))
      .toList();

  static Future<void> add(Highlight highlight) =>
      _b.put(highlight.id, highlight.toMap());

  static Future<void> delete(String id) => _b.delete(id);
}
