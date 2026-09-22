// Picks the right `setBrowserTitle` implementation for the current
// platform at compile time -- see browser_title_web.dart /
// browser_title_io.dart.
export 'browser_title_io.dart'
    if (dart.library.js_interop) 'browser_title_web.dart';
