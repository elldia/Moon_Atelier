import 'dart:async';

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
      var settings = ReadingSettings.fromMap(raw);
      // One-time migration: every save from before AppBrand had a settings
      // UI *forced* the Korean brand whenever locale was Korean — there was
      // no way to have chosen otherwise — so the first load after this
      // change switches those installs to the new international default.
      // The flag means later loads leave a real (possibly Korean) choice
      // made through Settings alone.
      if (raw['appNameMigrated'] != true) {
        if (settings.appName == AppBrand.moonlightLibrary) {
          settings = settings.copyWith(appName: AppBrand.moonAtelier);
        }
        unawaited(save(settings));
      }
      return settings;
    } catch (_) {
      return ReadingSettings.defaults;
    }
  }

  static Future<void> save(ReadingSettings settings) {
    final map = settings.toMap()..['appNameMigrated'] = true;
    return _b.put(_key, map);
  }
}
