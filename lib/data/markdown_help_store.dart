import 'package:hive_flutter/hive_flutter.dart';

/// Tracks whether the note editor's Markdown-shortcuts cheatsheet has
/// already been dismissed for good.
class MarkdownHelpStore {
  static const _boxName = 'app_meta';
  static const _key = 'markdown_help_seen';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final box = _box;
    if (box == null) {
      throw StateError('MarkdownHelpStore.init() must be awaited before use.');
    }
    return box;
  }

  static bool get hasSeen => _b.get(_key, defaultValue: false) as bool;

  static Future<void> markSeen() => _b.put(_key, true);
}
