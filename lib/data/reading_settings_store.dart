import 'package:hive_flutter/hive_flutter.dart';

import '../models/reading_settings.dart';

/// Persists the user's reading preferences (font, size, spacing, margins,
/// background, theme mode) in their own Hive box, separate from the
/// library so wiping one never touches the other.
class ReadingSettingsStore {
  static const _boxName = 'settings';
  static const _key = 'reading';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError(
        'ReadingSettingsStore.init() must be awaited before use.',
      );
    }
    return box;
  }

  static ReadingSettings load() {
    final raw = _b.get(_key) as Map?;
    if (raw == null) return ReadingSettings.defaults;
    try {
      return ReadingSettings.fromMap(raw);
    } catch (_) {
      return ReadingSettings.defaults;
    }
  }

  static Future<void> save(ReadingSettings settings) =>
      _b.put(_key, settings.toMap());
}
