import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

/// Persists comic cover thumbnails (small PNGs of each comic's first page,
/// see `buildComicCover`) in a lazy Hive box, keyed by book id — made once
/// per comic, so the cover grid never has to open the archives themselves.
/// An empty entry records that no cover could be made (so it isn't retried
/// on every visit). Covers aren't part of backups: they're regenerated.
class CoverStore {
  static const _boxName = 'comic_covers';
  static LazyBox? _box;

  static Future<void> init() async {
    _box = await Hive.openLazyBox(_boxName);
  }

  static LazyBox get _b {
    final box = _box;
    if (box == null) {
      throw StateError('CoverStore.init() must be awaited before use.');
    }
    return box;
  }

  /// The stored cover: PNG bytes, an empty list if making one failed, or
  /// null if none has been made yet.
  static Future<Uint8List?> load(String bookId) async {
    final bytes = await _b.get(bookId);
    return bytes is Uint8List ? bytes : null;
  }

  static Future<void> save(String bookId, Uint8List png) => _b.put(bookId, png);

  static Future<void> delete(String bookId) => _b.delete(bookId);
}
