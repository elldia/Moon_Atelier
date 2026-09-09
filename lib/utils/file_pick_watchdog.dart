// Picks the right `pickFileWithWatchdog` implementation for the current
// platform at compile time — see file_pick_watchdog_web.dart for why the
// web build needs the extra watchdog logic, and file_pick_watchdog_io.dart
// for why native platforms don't.
export 'file_pick_watchdog_io.dart'
    if (dart.library.js_interop) 'file_pick_watchdog_web.dart';
