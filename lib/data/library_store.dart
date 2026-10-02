import 'dart:async';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/book.dart';
import '../utils/text_decoder.dart';

/// Persists the library in two Hive boxes, so both survive an app restart:
/// - `library`: each book's small metadata (name, format, last reading
///   position, progress, folder...), kept in memory and rewritten on every
///   position save;
/// - `library_bytes`: each book's file contents, in a lazy box -- read from
///   disk only when a book is opened, and written only when it's added or
///   its content edited.
///
/// The two used to share one box, so every position save rewrote the whole
/// book file (Hive appends each write, growing the file by a full copy
/// until it compacts) and opening the app loaded every book into memory.
/// [init] moves any library saved that way over to this layout.
class LibraryStore {
  static const _boxName = 'library';
  static const _bytesBoxName = 'library_bytes';
  static Box? _box;
  static LazyBox? _bytesBox;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _bytesBox = await Hive.openLazyBox(_bytesBoxName);
    await _moveLegacyBytes();
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError('LibraryStore.init() must be awaited before use.');
    }
    return box;
  }

  static LazyBox get _bytes {
    final box = _bytesBox;
    if (box == null) {
      throw StateError('LibraryStore.init() must be awaited before use.');
    }
    return box;
  }

  /// One-time migration from the single-box layout: each book's bytes move
  /// to the bytes box (written first, so an interrupted run just repeats
  /// next launch), its metadata is rewritten without them, and a TXT's
  /// character count -- shown in the library list -- is worked out while
  /// the text is at hand. The old box is then compacted to drop the
  /// stale full-book copies.
  static Future<void> _moveLegacyBytes() async {
    var moved = 0;
    for (final key in _b.keys.cast<String>().toList()) {
      final raw = _b.get(key) as Map;
      final bytes = raw['bytes'];
      if (bytes is! Uint8List) continue;
      await _bytes.put(key, bytes);
      final meta = Map<String, dynamic>.from(raw)..remove('bytes');
      if (meta['format'] == BookFormat.txt.name && meta['charCount'] == null) {
        meta['charCount'] = decodeTextBytes(bytes).length;
      }
      await _b.put(key, meta);
      moved++;
    }
    if (moved > 0) await _b.compact();
  }

  /// Closes and reopens both boxes, forcing a fresh IndexedDB connection.
  /// Works around a known WebKit/iOS bug where the first IndexedDB
  /// transaction in a session — especially one writing a large binary
  /// payload like a book's bytes — can hang forever; reopening the
  /// connection reliably unsticks it (mirroring what a manual page reload
  /// does, per Apple/WebKit bug reports).
  static Future<void> _reopenBoxes() async {
    await _box?.close();
    await _bytesBox?.close();
    Future<T> reopen<T>(Future<T> open) => open.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('reopening the library boxes'),
    );
    _box = await reopen(Hive.openBox(_boxName));
    _bytesBox = await reopen(Hive.openLazyBox(_bytesBoxName));
  }

  /// A put with the WebKit hang workaround: one timed attempt, then a
  /// reopen and a longer second try.
  static Future<void> _put(BoxBase Function() box, String key, Object value) async {
    try {
      await box().put(key, value).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('saving to the library'),
      );
    } on TimeoutException {
      await _reopenBoxes();
      await box().put(key, value).timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw TimeoutException('saving to the library (after retry)'),
      );
    }
  }

  /// Every book's metadata, most recently opened (or added) first. Book
  /// contents stay on disk -- see [loadBytes].
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

  /// Adds a new book: its contents, then its metadata (so a book never
  /// lists without contents to open).
  static Future<void> add(Book book, Uint8List bytes) async {
    await _put(() => _bytes, book.id, bytes);
    await save(book);
  }

  /// Saves a book's metadata only -- cheap enough to call on every reading
  /// position change.
  static Future<void> save(Book book) => _put(() => _b, book.id, _toMap(book));

  /// Replaces a book's contents (e.g. an edited note).
  static Future<void> saveBytes(String id, Uint8List bytes) =>
      _put(() => _bytes, id, bytes);

  /// A book's contents, read from disk; null if they're missing.
  static Future<Uint8List?> loadBytes(String id) async {
    final bytes = await _bytes.get(id);
    return bytes is Uint8List ? bytes : null;
  }

  static Future<void> delete(String id) async {
    await _b.delete(id);
    await _bytes.delete(id);
  }

  static Map<String, dynamic> _toMap(Book book) => {
    'name': book.name,
    'format': book.format.name,
    'addedAt': book.addedAt.toIso8601String(),
    'lastOpenedAt': book.lastOpenedAt?.toIso8601String(),
    'modifiedAt': book.modifiedAt?.toIso8601String(),
    'position': book.position,
    'progress': book.progress,
    'folderId': book.folderId,
    'charCount': book.charCount,
  };

  static Book _fromMap(String id, Map raw) {
    final lastOpenedRaw = raw['lastOpenedAt'] as String?;
    final modifiedRaw = raw['modifiedAt'] as String?;
    return Book(
      id: id,
      name: raw['name'] as String,
      format: BookFormat.values.byName(raw['format'] as String),
      addedAt: DateTime.parse(raw['addedAt'] as String),
      lastOpenedAt: lastOpenedRaw != null
          ? DateTime.parse(lastOpenedRaw)
          : null,
      modifiedAt: modifiedRaw != null ? DateTime.parse(modifiedRaw) : null,
      position: raw['position'],
      progress: (raw['progress'] as num?)?.toDouble(),
      folderId: raw['folderId'] as String?,
      charCount: (raw['charCount'] as num?)?.toInt(),
    );
  }
}
