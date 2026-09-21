import 'package:hive_flutter/hive_flutter.dart';

import '../models/comic_settings.dart';

/// Persists the user's comic-viewer preferences (view mode, direction,
/// image quality) in the shared settings Hive box, alongside — but under a
/// separate key from — [ReadingSettingsStore]'s e-book preferences.
class ComicSettingsStore {
  static const _boxName = 'settings';
  static const _key = 'comic';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError('ComicSettingsStore.init() must be awaited before use.');
    }
    return box;
  }

  static ComicSettings load() {
    final raw = _b.get(_key) as Map?;
    if (raw == null) return ComicSettings.defaults;
    try {
      return ComicSettings.fromMap(raw);
    } catch (_) {
      return ComicSettings.defaults;
    }
  }

  static Future<void> save(ComicSettings settings) =>
      _b.put(_key, settings.toMap());
}
