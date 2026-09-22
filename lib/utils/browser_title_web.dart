import 'dart:js_interop';

/// Sets the browser tab's title directly (`document.title`) -- separate
/// from `web/index.html`'s static `<title>`, which only covers the very
/// first paint. Screens call this so the tab reflects which of the app's
/// two libraries (or neither, on the home screen) is currently open.
void setBrowserTitle(String title) {
  _documentTitle = title;
}

@JS('document.title')
external set _documentTitle(String value);
