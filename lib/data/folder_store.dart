import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../models/folder.dart';
import 'library_store.dart';

/// Persists the library's (flat, single-level) folders in a Hive box.
class FolderStore {
  static const _boxName = 'folders';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError('FolderStore.init() must be awaited before use.');
    }
    return box;
  }

  static List<Folder> loadAll() {
    final folders = _b.keys
        .cast<String>()
        .map((key) => Folder.fromMap(key, _b.get(key) as Map))
        .toList();
    folders.sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  static Future<void> add(Folder folder) => _b.put(folder.id, folder.toMap());

  static Future<void> delete(String id) => _b.delete(id);

  /// Gives every folder saved before folders had a [Folder.kind] (back when
  /// one folder list was shared by the e-book and comic libraries) the kind
  /// of the books filed in it: comics only → a comic folder, anything else
  /// (including empty) → an e-book folder. A folder holding both keeps its
  /// e-books, and its comics move to a new comic folder of the same name,
  /// so neither library loses its grouping. Cheap once everything has a
  /// kind — call after [LibraryStore.init]. A backup restore passes
  /// [ids] explicitly, since restoring writes each folder back (as an
  /// e-book folder) before its kind can be worked out.
  static Future<void> assignLegacyKinds([Iterable<String>? ids]) async {
    final legacyIds = [
      for (final key in ids ?? _b.keys.cast<String>())
        if (ids != null || (_b.get(key) as Map)['kind'] == null) key,
    ];
    if (legacyIds.isEmpty) return;
    final books = LibraryStore.loadAll();
    for (final id in legacyIds) {
      final folder = Folder.fromMap(id, _b.get(id) as Map);
      final inside = books.where((b) => b.folderId == id).toList();
      final comics = inside.where((b) => b.format.kind == BookKind.comic);
      final hasEbooks = inside.any((b) => b.format.kind == BookKind.ebook);
      if (comics.isNotEmpty && !hasEbooks) {
        await add(_withKind(folder, BookKind.comic));
        continue;
      }
      await add(_withKind(folder, BookKind.ebook));
      if (comics.isEmpty) continue;
      final comicFolder = Folder(
        id: const Uuid().v4(),
        name: folder.name,
        createdAt: folder.createdAt,
        kind: BookKind.comic,
      );
      await add(comicFolder);
      for (final book in comics) {
        await LibraryStore.save(book.copyWith(folderId: comicFolder.id));
      }
    }
  }

  static Folder _withKind(Folder folder, BookKind kind) => Folder(
    id: folder.id,
    name: folder.name,
    createdAt: folder.createdAt,
    kind: kind,
  );
}
