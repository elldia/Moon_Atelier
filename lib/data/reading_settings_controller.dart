import 'package:flutter/foundation.dart';

import '../models/reading_settings.dart';
import 'reading_settings_store.dart';

/// App-wide singleton holding the current [ReadingSettings]. Every screen
/// that reads or edits reading preferences (library screen, text/EPUB
/// viewers, the settings sheet) listens to the same instance, so a change
/// made mid-read from a modal sheet is reflected immediately without
/// re-navigating.
class ReadingSettingsController extends ValueNotifier<ReadingSettings> {
  ReadingSettingsController._(super.value);

  static ReadingSettingsController instance = ReadingSettingsController._(
    ReadingSettings.defaults,
  );

  static Future<void> init() async {
    instance.value = ReadingSettingsStore.load();
  }

  void update(ReadingSettings Function(ReadingSettings current) updater) {
    value = updater(value);
    ReadingSettingsStore.save(value);
  }
}
