import 'package:hive_flutter/hive_flutter.dart';

import '../models/bookmark.dart';

/// Persists per-book reading-position bookmarks in their own Hive box.
class BookmarkStore {
  static const _boxName = 'bookmarks';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError('BookmarkStore.init() must be awaited before use.');
    }
    return box;
  }

  static List<Bookmark> forBook(String bookId) {
    final items = _b.keys
        .cast<String>()
        .where((key) => (_b.get(key) as Map)['bookId'] == bookId)
        .map((key) => Bookmark.fromMap(key, _b.get(key) as Map))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static List<Bookmark> loadAll() => _b.keys
      .cast<String>()
      .map((key) => Bookmark.fromMap(key, _b.get(key) as Map))
      .toList();

  static Future<void> add(Bookmark bookmark) =>
      _b.put(bookmark.id, bookmark.toMap());

  static Future<void> delete(String id) => _b.delete(id);
}
