import 'package:hive_flutter/hive_flutter.dart';

/// Tracks whether the first-run help dialog has already been shown.
class OnboardingStore {
  static const _boxName = 'app_meta';
  static const _key = 'onboarding_seen';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError('OnboardingStore.init() must be awaited before use.');
    }
    return box;
  }

  static bool get hasSeen => _b.get(_key, defaultValue: false) as bool;

  static Future<void> markSeen() => _b.put(_key, true);
}
