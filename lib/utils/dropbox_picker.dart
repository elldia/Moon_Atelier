import 'dart:async';
import 'dart:js_interop';

/// A file the user picked via the Dropbox Chooser widget — [link] is a
/// short-lived direct-download URL (since the widget is opened with
/// `linkType: "direct"`), fetchable with a plain HTTP GET.
class DropboxFileResult {
  final String name;
  final String link;
  const DropboxFileResult({required this.name, required this.link});
}

/// True once Dropbox's own `dropins.js` (loaded from web/index.html) has
/// defined the global `Dropbox` object — false if the app key placeholder
/// there was never replaced with a real one, since Dropbox's script simply
/// no-ops without a valid key rather than throwing.
bool get isDropboxChooserAvailable => _dropbox != null;

/// Opens the Dropbox Chooser popup and resolves with the single file the
/// user picked, or null if they cancelled. Returns null immediately (no
/// popup) if [isDropboxChooserAvailable] is false.
Future<DropboxFileResult?> chooseDropboxFile({List<String>? extensions}) {
  final dropbox = _dropbox;
  if (dropbox == null) return Future.value(null);

  final completer = Completer<DropboxFileResult?>();
  final onSuccess = (JSArray<_DropboxFile> files) {
    final list = files.toDart;
    if (list.isEmpty) {
      completer.complete(null);
    } else {
      final f = list.first;
      completer.complete(DropboxFileResult(name: f.name, link: f.link));
    }
  }.toJS;
  final onCancel = () {
    if (!completer.isCompleted) completer.complete(null);
  }.toJS;

  dropbox.choose(
    _ChooseOptions(
      success: onSuccess,
      cancel: onCancel,
      linkType: 'direct',
      multiselect: false,
      extensions: extensions?.map((e) => e.toJS).toList().toJS,
    ),
  );
  return completer.future;
}

@JS('Dropbox')
external _Dropbox? get _dropbox;

extension type _Dropbox._(JSObject _) implements JSObject {
  external void choose(_ChooseOptions options);
}

extension type _ChooseOptions._(JSObject _) implements JSObject {
  external factory _ChooseOptions({
    required JSFunction success,
    required JSFunction cancel,
    String linkType,
    bool multiselect,
    JSArray<JSString>? extensions,
  });
}

extension type _DropboxFile._(JSObject _) implements JSObject {
  external String get name;
  external String get link;
}
