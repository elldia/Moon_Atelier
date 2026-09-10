import 'dart:async';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/book.dart';

/// Persists the library list and each book's bytes + last reading position
/// in a Hive box, so both survive an app restart.
class LibraryStore {
  static const _boxName = 'library';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError('LibraryStore.init() must be awaited before use.');
    }
    return box;
  }

  /// Closes and reopens the underlying IndexedDB-backed box, forcing a
  /// fresh connection. Works around a known WebKit/iOS bug where the first
  /// IndexedDB transaction in a session — especially one writing a large
  /// binary payload like a book's bytes — can hang forever; reopening the
  /// connection reliably unsticks it (mirroring what a manual page reload
  /// does, per Apple/WebKit bug reports).
  static Future<void> _reopenBox() async {
    await _box?.close();
    _box = await Hive.openBox(_boxName).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('reopening the library box'),
    );
  }

  static List<Book> loadAll() {
    final books = _b.keys
        .map((key) => _fromMap(key as String, _b.get(key) as Map))
        .toList();
    books.sort((a, b) {
      final aTime = a.lastOpenedAt ?? a.addedAt;
      final bTime = b.lastOpenedAt ?? b.addedAt;
      return bTime.compareTo(aTime);
    });
    return books;
  }

  static Future<void> save(Book book) async {
    final map = _toMap(book);
    try {
      await _b.put(book.id, map).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('saving to the library box'),
      );
    } on TimeoutException {
      await _reopenBox();
      await _b.put(book.id, map).timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw TimeoutException('saving to the library box (after retry)'),
      );
    }
  }

  static Future<void> delete(String id) => _b.delete(id);

  static Map<String, dynamic> _toMap(Book book) => {
    'name': book.name,
    'format': book.format.name,
    'bytes': book.bytes,
    'addedAt': book.addedAt.toIso8601String(),
    'lastOpenedAt': book.lastOpenedAt?.toIso8601String(),
    'modifiedAt': book.modifiedAt?.toIso8601String(),
    'position': book.position,
    'progress': book.progress,
    'folderId': book.folderId,
  };

  static Book _fromMap(String id, Map raw) {
    final lastOpenedRaw = raw['lastOpenedAt'] as String?;
    final modifiedRaw = raw['modifiedAt'] as String?;
    return Book(
      id: id,
      name: raw['name'] as String,
      format: BookFormat.values.byName(raw['format'] as String),
      bytes: raw['bytes'] as Uint8List,
      addedAt: DateTime.parse(raw['addedAt'] as String),
      lastOpenedAt: lastOpenedRaw != null
          ? DateTime.parse(lastOpenedRaw)
          : null,
      modifiedAt: modifiedRaw != null ? DateTime.parse(modifiedRaw) : null,
      position: raw['position'],
      progress: (raw['progress'] as num?)?.toDouble(),
      folderId: raw['folderId'] as String?,
    );
  }
}
