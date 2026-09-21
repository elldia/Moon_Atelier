import 'package:flutter/foundation.dart';

import '../models/comic_settings.dart';
import 'comic_settings_store.dart';

/// App-wide singleton holding the current [ComicSettings], mirroring
/// [ReadingSettingsController] — every comic the user opens shares the same
/// view mode/direction/quality until they change it again.
class ComicSettingsController extends ValueNotifier<ComicSettings> {
  ComicSettingsController._(super.value);

  static ComicSettingsController instance = ComicSettingsController._(
    ComicSettings.defaults,
  );

  static Future<void> init() async {
    instance.value = ComicSettingsStore.load();
  }

  void update(ComicSettings Function(ComicSettings current) updater) {
    value = updater(value);
    ComicSettingsStore.save(value);
  }
}
