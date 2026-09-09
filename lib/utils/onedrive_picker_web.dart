import 'dart:async';
import 'dart:js_interop';

/// Replace with a real Client ID from https://entra.microsoft.com (App
/// registrations → New registration; add a "Single-page application"
/// platform with this site's URL as a redirect URI, and grant the
/// "Files.Read" Microsoft Graph delegated permission). Until this is a
/// real value, [isOneDriveConfigured] is false and the OneDrive import
/// option shows a "not configured" message instead of failing silently.
const _oneDriveClientId = 'YOUR_ONEDRIVE_CLIENT_ID';

bool get isOneDriveConfigured => _oneDriveClientId != 'YOUR_ONEDRIVE_CLIENT_ID';

class OneDriveFileResult {
  final String name;
  final String downloadUrl;
  const OneDriveFileResult({required this.name, required this.downloadUrl});
}

/// Opens the OneDrive file picker popup and resolves with the single file
/// the user picked, or null if they cancelled/it errored. Returns null
/// immediately (no popup) if [isOneDriveConfigured] is false or the
/// `OneDrive.js` script (loaded from web/index.html) hasn't defined the
/// global `OneDrive` object.
Future<OneDriveFileResult?> chooseOneDriveFile({
  required String filter,
  required String redirectUri,
}) {
  final oneDrive = _oneDrive;
  if (oneDrive == null || !isOneDriveConfigured) return Future.value(null);

  final completer = Completer<OneDriveFileResult?>();
  final onSuccess = (_PickerResponse response) {
    final items = response.value.toDart;
    if (items.isEmpty) {
      completer.complete(null);
    } else {
      final item = items.first;
      final url = item.downloadUrl;
      completer.complete(
        url == null
            ? null
            : OneDriveFileResult(name: item.name, downloadUrl: url),
      );
    }
  }.toJS;
  final onCancel = () {
    if (!completer.isCompleted) completer.complete(null);
  }.toJS;
  final onError = (JSAny error) {
    if (!completer.isCompleted) completer.complete(null);
  }.toJS;

  oneDrive.open(
    _OpenOptions(
      clientId: _oneDriveClientId,
      action: 'download',
      multiSelect: false,
      advanced: _AdvancedOptions(filter: filter, redirectUri: redirectUri),
      success: onSuccess,
      cancel: onCancel,
      error: onError,
    ),
  );
  return completer.future;
}

@JS('OneDrive')
external _OneDrive? get _oneDrive;

extension type _OneDrive._(JSObject _) implements JSObject {
  external void open(_OpenOptions options);
}

extension type _OpenOptions._(JSObject _) implements JSObject {
  external factory _OpenOptions({
    required String clientId,
    required String action,
    required bool multiSelect,
    required _AdvancedOptions advanced,
    required JSFunction success,
    required JSFunction cancel,
    required JSFunction error,
  });
}

extension type _AdvancedOptions._(JSObject _) implements JSObject {
  external factory _AdvancedOptions({String? filter, String? redirectUri});
}

extension type _PickerResponse._(JSObject _) implements JSObject {
  external JSArray<_PickerItem> get value;
}

extension type _PickerItem._(JSObject _) implements JSObject {
  external String get name;

  // Microsoft Graph's actual key contains '@' and '.', which isn't a valid
  // Dart identifier -- @JS() lets us look it up under its real name anyway.
  @JS('@microsoft.graph.downloadUrl')
  external String? get downloadUrl;
}
