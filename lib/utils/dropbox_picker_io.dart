import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../widgets/dropbox_browser_dialog.dart';

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
  return showDropboxBrowserDialog(
    context,
    session: session,
    extensions: extensions,
  );
}

/// One entry (file or folder) returned by Dropbox's `files/list_folder`.
class DropboxEntry {
  final String name;
  final String pathLower;
  final bool isDirectory;
  final int? size;

  const DropboxEntry({
    required this.name,
    required this.pathLower,
    required this.isDirectory,
    this.size,
  });
}

/// An authenticated Dropbox API session: just a bearer token, since every
/// call here is a stateless REST request -- there's no connection to hold
/// open or close, unlike [FtpSession]. The token is never persisted (kept
/// only for this dialog's lifetime), so re-picking from Dropbox later
/// means signing in again, the same tradeoff FTP's un-remembered
/// credentials already make.
class DropboxSession {
  final String _token;
  DropboxSession._(this._token);

  static Future<DropboxSession?> authenticate() async {
    final verifier = _generateCodeVerifier();
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
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

  /// Lists [path] (`''` for the root), directories first, both groups
  /// case-insensitively alphabetical -- mirroring [FtpSession.list].
  /// Follows `has_more`/cursor pagination internally so a large folder
  /// still comes back as one complete list.
  Future<List<DropboxEntry>> list(String path) async {
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

  List<DropboxEntry> _parseEntries(List raw) {
    final result = <DropboxEntry>[];
    for (final e in raw) {
      final map = e as Map;
      final tag = map['.tag'] as String?;
      if (tag != 'folder' && tag != 'file') continue;
      result.add(
        DropboxEntry(
          name: map['name'] as String,
          pathLower: map['path_lower'] as String,
          isDirectory: tag == 'folder',
          size: tag == 'file' ? (map['size'] as num?)?.toInt() : null,
        ),
      );
    }
    return result;
  }

  /// A short-lived, unauthenticated direct-download link for [path] --
  /// what lets [DropboxFileResult.link] be a plain `http.get` on the
  /// caller's side instead of every downloader needing this session's
  /// bearer token.
  Future<String> temporaryLink(String path) async {
    final response = await http.post(
      Uri.https('api.dropboxapi.com', '/2/files/get_temporary_link'),
      headers: _jsonHeaders,
      body: jsonEncode({'path': path}),
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

const _codeVerifierChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/// A random 64-character PKCE code verifier (RFC 7636 allows 43-128), from
/// the RFC's own unreserved-character alphabet.
String _generateCodeVerifier() {
  final rand = Random.secure();
  return List.generate(
    64,
    (_) => _codeVerifierChars[rand.nextInt(_codeVerifierChars.length)],
  ).join();
}
