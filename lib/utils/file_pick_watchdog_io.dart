import 'package:file_picker/file_picker.dart';

/// Native (Android/iOS/desktop) counterpart of the web build's
/// `file_pick_watchdog_web.dart`. The watchdog there exists purely to work
/// around an iOS Safari quirk in the browser's `<input type="file">` flow
/// (see that file) — a real native file picker doesn't have it, so this is a
/// plain passthrough.
Future<PlatformFile?> pickFileWithWatchdog({
  required List<String> allowedExtensions,
  Duration graceAfterRefocus = const Duration(seconds: 6),
}) {
  return FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
  );
}
