/// Native (Android/iOS/desktop) stub for the web build's
/// `onedrive_picker_web.dart`. OneDrive import stays a web-only source for
/// now -- a native version needs its own OAuth flow and a separate Entra
/// mobile app registration, deliberately out of scope here. Reporting
/// "unavailable" routes through library_screen.dart's existing
/// not-configured message instead of needing a separate native-specific
/// code path.
class OneDriveFileResult {
  final String name;
  final String downloadUrl;
  const OneDriveFileResult({required this.name, required this.downloadUrl});
}

bool get isOneDriveConfigured => false;

Future<OneDriveFileResult?> chooseOneDriveFile({
  required String filter,
  required String redirectUri,
}) => Future.value(null);
