import 'package:hive_flutter/hive_flutter.dart';

import '../models/folder.dart';

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
}
