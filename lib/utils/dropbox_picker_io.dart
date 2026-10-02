import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../l10n/strings.dart';
import '../widgets/cloud_browser_dialog.dart';
import 'pkce.dart';

/// A file the user picked from their Dropbox -- [link] is a short-lived
/// (per Dropbox's docs, ~4 hour) direct-download URL from
/// `files/get_temporary_link`, fetchable with a plain HTTP GET, matching
/// the shape [chooseDropboxFile]'s web counterpart already hands back so
/// library_screen.dart's shared download step doesn't need to know which
/// platform picked the file.
class DropboxFileResult {
  final String name;
  final String link;
  const DropboxFileResult({required this.name, required this.link});
}

/// Dropbox App Console (https://www.dropbox.com/developers/apps) -> your
/// app -> Settings -> "App key". The app also needs
/// "moonatelier://dropbox-auth" (see _redirectUri below) added under
/// "OAuth 2" -> "Redirect URIs" before this will work -- until a real key
/// replaces this placeholder, [isDropboxChooserAvailable] stays false, the
/// same convention the web build's own Dropbox/OneDrive app keys use.
const dropboxAppKey = 'jy0y83lq9ocl8cx';

const _redirectUri = 'moonatelier://dropbox-auth';
const _callbackUrlScheme = 'moonatelier';

/// True when a real app key has been set. Native Dropbox import is
/// Android/iOS only for now: `flutter_web_auth_2`'s desktop platforms
/// (Windows/macOS/Linux) redirect through a local loopback server on a
/// random port rather than this custom URL scheme, which wouldn't match
/// the single fixed redirect URI registered with the Dropbox app above.
bool get isDropboxChooserAvailable =>
    dropboxAppKey != 'YOUR_DROPBOX_APP_KEY' &&
    (Platform.isAndroid || Platform.isIOS);

/// Runs the OAuth (PKCE) authorize-and-approve flow in a Custom Tab /
/// ASWebAuthenticationSession, then shows the folder-browser dialog built
/// on top of the resulting session. Returns null if the user cancels
/// either step, or if [isDropboxChooserAvailable] is false.
Future<DropboxFileResult?> chooseDropboxFile({
  required BuildContext context,
  List<String>? extensions,
}) async {
  if (!isDropboxChooserAvailable) return null;
  final session = await DropboxSession.authenticate();
  if (session == null || !context.mounted) return null;
  final picked = await showCloudBrowserDialog(
    context,
    source: session,
    extensions: extensions,
  );
  return picked == null
      ? null
      : DropboxFileResult(name: picked.name, link: picked.url);
}

/// An authenticated Dropbox API session: just a bearer token, since every
/// call here is a stateless REST request -- there's no connection to hold
/// open or close, unlike [FtpSession]. The token is never persisted (kept
/// only for this dialog's lifetime), so re-picking from Dropbox later
/// means signing in again, the same tradeoff FTP's un-remembered
/// credentials already make.
/// Entries are addressed by their lowercase path (`id`), the root by ''.
class DropboxSession implements CloudDriveSource {
  final String _token;
  DropboxSession._(this._token);

  @override
  String get title => tr('source_dropbox');

  static Future<DropboxSession?> authenticate() async {
    final verifier = generateCodeVerifier();
    final challenge = codeChallengeFor(verifier);
    final authorizeUrl = Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': dropboxAppKey,
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'redirect_uri': _redirectUri,
      // Forces a short-lived access-token-only response regardless of the
      // app's own "Access token expiration" console setting, so there's
      // never a refresh token to think about storing.
      'token_access_type': 'online',
    });

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: _callbackUrlScheme,
      );
    } catch (_) {
      return null; // user cancelled, or the auth page reported an error
    }
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) return null;

    final tokenResponse = await http.post(
      Uri.https('api.dropboxapi.com', '/oauth2/token'),
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': dropboxAppKey,
        'redirect_uri': _redirectUri,
        'code_verifier': verifier,
      },
    );
    if (tokenResponse.statusCode != 200) return null;
    final data = jsonDecode(tokenResponse.body) as Map;
    final token = data['access_token'] as String?;
    return token == null ? null : DropboxSession._(token);
  }

  Map<String, String> get _jsonHeaders => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  /// Lists [folderId] (a lowercase path; null for the root), directories
  /// first, both groups case-insensitively alphabetical -- mirroring
  /// [FtpSession.list]. Follows `has_more`/cursor pagination internally so
  /// a large folder still comes back as one complete list.
  @override
  Future<List<CloudEntry>> list(String? folderId) async {
    final path = folderId ?? '';
    var response = await http.post(
      Uri.https('api.dropboxapi.com', '/2/files/list_folder'),
      headers: _jsonHeaders,
      body: jsonEncode({'path': path}),
    );
    if (response.statusCode != 200) {
      throw Exception('Dropbox list_folder failed (${response.statusCode})');
    }
    var data = jsonDecode(response.body) as Map;
    final entries = _parseEntries(data['entries'] as List);
    while (data['has_more'] == true) {
      response = await http.post(
        Uri.https('api.dropboxapi.com', '/2/files/list_folder/continue'),
        headers: _jsonHeaders,
        body: jsonEncode({'cursor': data['cursor']}),
      );
      if (response.statusCode != 200) break;
      data = jsonDecode(response.body) as Map;
      entries.addAll(_parseEntries(data['entries'] as List));
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  List<CloudEntry> _parseEntries(List raw) {
    final result = <CloudEntry>[];
    for (final e in raw) {
      final map = e as Map;
      final tag = map['.tag'] as String?;
      if (tag != 'folder' && tag != 'file') continue;
      result.add(
        CloudEntry(
          id: map['path_lower'] as String,
          name: map['name'] as String,
          isDirectory: tag == 'folder',
          size: tag == 'file' ? (map['size'] as num?)?.toInt() : null,
        ),
      );
    }
    return result;
  }

  /// A short-lived, unauthenticated direct-download link for [file] --
  /// what lets [DropboxFileResult.link] be a plain `http.get` on the
  /// caller's side instead of every downloader needing this session's
  /// bearer token.
  @override
  Future<String> downloadUrl(CloudEntry file) async {
    final response = await http.post(
      Uri.https('api.dropboxapi.com', '/2/files/get_temporary_link'),
      headers: _jsonHeaders,
      body: jsonEncode({'path': file.id}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Dropbox get_temporary_link failed (${response.statusCode})',
      );
    }
    final data = jsonDecode(response.body) as Map;
    return data['link'] as String;
  }
}
