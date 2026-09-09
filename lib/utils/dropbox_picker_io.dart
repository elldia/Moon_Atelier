/// Native (Android/iOS/desktop) stub for the web build's
/// `dropbox_picker_web.dart`. Dropbox import stays a web-only source for
/// now -- a native version needs its own OAuth flow and a separate Dropbox
/// app registration, deliberately out of scope here. Reporting "unavailable"
/// routes through library_screen.dart's existing not-configured message
/// instead of needing a separate native-specific code path.
class DropboxFileResult {
  final String name;
  final String link;
  const DropboxFileResult({required this.name, required this.link});
}

bool get isDropboxChooserAvailable => false;

Future<DropboxFileResult?> chooseDropboxFile({List<String>? extensions}) =>
    Future.value(null);
