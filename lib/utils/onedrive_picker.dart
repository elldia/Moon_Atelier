// Picks the right OneDrive picker implementation for the current platform
// at compile time -- see onedrive_picker_web.dart / onedrive_picker_io.dart.
export 'onedrive_picker_io.dart' if (dart.library.js_interop) 'onedrive_picker_web.dart';
