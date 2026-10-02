import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../l10n/strings.dart';
import '../widgets/cloud_browser_dialog.dart';
import 'pkce.dart';

/// A file the user picked from their OneDrive -- [downloadUrl] is Graph's
/// short-lived, pre-authenticated `@microsoft.graph.downloadUrl`, fetchable
/// with a plain HTTP GET, the same shape the web build's picker hands back.
class OneDriveFileResult {
  final String name;
  final String downloadUrl;
  const OneDriveFileResult({required this.name, required this.downloadUrl});
}

/// Application (client) ID of the "Moon Atelier" app registration in
/// Microsoft Entra (portal.azure.com -> App registrations), registered for
/// "any Entra ID tenant + personal Microsoft accounts" with a "Mobile and
/// desktop applications" redirect URI of [oneDriveRedirectUri] and the
/// delegated Microsoft Graph permission Files.Read. A public client: no
/// secret, PKCE instead.
const oneDriveClientId = '2a74492a-b511-46d8-bd7a-8c6603f9f8d3';

/// Where Microsoft sends the user back after sign-in; each must be
/// registered on the app exactly.
/// - Android/iOS ("Mobile and desktop applications" platform): this custom
///   scheme, which the Android manifest already routes back into the app
///   for Dropbox (flutter_web_auth_2's CallbackActivity).
/// - Web ("Single-page application" platform): web/onedrive-auth.html next
///   to the app, which hands the result back to the app's window — see
///   [oneDriveRedirectUri].
const _nativeRedirectUri = 'moonatelier://onedrive-auth';
const _callbackUrlScheme = 'moonatelier';

/// The redirect URI for the running platform. On the web it's resolved
/// against the page itself, so the deployed site (e.g.
/// https://elldia.github.io/Moon_Atelier/) and a local `flutter run` each
/// get their own onedrive-auth.html.
String get oneDriveRedirectUri => kIsWeb
    ? Uri.base.resolve('onedrive-auth.html').toString()
    : _nativeRedirectUri;

/// Read-only access to the user's files is all import needs.
const _scope = 'Files.Read';

/// The web, Android and iOS. Not desktop: flutter_web_auth_2's desktop
/// platforms redirect through a loopback server, not the custom scheme.
bool get isOneDriveConfigured =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Signs in to Microsoft (OAuth 2.0 authorization code + PKCE, in a Custom
/// Tab / ASWebAuthenticationSession, or a popup window on the web), then
/// shows the folder browser over the user's OneDrive. Returns null if the
/// user cancels either step.
///
/// On the web this must be called straight from the tap that asked for it
/// (no awaits before it), so browsers let the sign-in popup open.
Future<OneDriveFileResult?> chooseOneDriveFile({
  required BuildContext context,
  required List<String> extensions,
}) async {
  if (!isOneDriveConfigured) return null;
  final session = await OneDriveSession.authenticate();
  if (session == null || !context.mounted) return null;
  final picked = await showCloudBrowserDialog(
    context,
    source: session,
    extensions: extensions,
  );
  return picked == null
      ? null
      : OneDriveFileResult(name: picked.name, downloadUrl: picked.url);
}

/// The Microsoft identity platform's "common" endpoint, which accepts both
/// personal Microsoft accounts and work/school (Entra ID) accounts.
const _authority = 'login.microsoftonline.com';
const _authorizePath = '/common/oauth2/v2.0/authorize';
const _tokenPath = '/common/oauth2/v2.0/token';
const _graphHost = 'graph.microsoft.com';

/// The sign-in page URL for a PKCE [codeChallenge].
@visibleForTesting
Uri oneDriveAuthorizeUrl(String codeChallenge) =>
    Uri.https(_authority, _authorizePath, {
      'client_id': oneDriveClientId,
      'response_type': 'code',
      'redirect_uri': oneDriveRedirectUri,
      'response_mode': 'query',
      'scope': _scope,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

/// An authenticated Microsoft Graph session over the signed-in user's
/// OneDrive. Like Dropbox's session, the access token lives only as long as
/// this object (never persisted); signing in again later is usually one
/// tap, since the sign-in page remembers the Microsoft account.
class OneDriveSession implements CloudDriveSource {
  final String _token;
  final http.Client _client;

  OneDriveSession(this._token, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get title => tr('source_onedrive');

  static Future<OneDriveSession?> authenticate() async {
    final verifier = generateCodeVerifier();
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: oneDriveAuthorizeUrl(codeChallengeFor(verifier)).toString(),
        callbackUrlScheme: _callbackUrlScheme,
      );
    } catch (_) {
      return null; // user cancelled, or the sign-in page reported an error
    }
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) return null;
    return exchangeCode(code: code, verifier: verifier);
  }

  /// Trades the authorization [code] for an access token.
  @visibleForTesting
  static Future<OneDriveSession?> exchangeCode({
    required String code,
    required String verifier,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    final response = await c.post(
      Uri.https(_authority, _tokenPath),
      body: {
        'client_id': oneDriveClientId,
        'grant_type': 'authorization_code',
        'scope': _scope,
        'code': code,
        'redirect_uri': oneDriveRedirectUri,
        'code_verifier': verifier,
      },
    );
    if (response.statusCode != 200) return null;
    final token = (jsonDecode(response.body) as Map)['access_token'];
    return token is String ? OneDriveSession(token, client: c) : null;
  }

  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  /// Lists [folderId] (a drive item id; null for the drive's root),
  /// folders first, both groups case-insensitively alphabetical. Follows
  /// `@odata.nextLink` paging so a large folder comes back whole.
  @override
  Future<List<CloudEntry>> list(String? folderId) async {
    final path = folderId == null
        ? '/v1.0/me/drive/root/children'
        : '/v1.0/me/drive/items/${Uri.encodeComponent(folderId)}/children';
    Uri? next = Uri.https(_graphHost, path, {
      r'$select': 'id,name,size,folder,file',
      r'$top': '200',
    });
    final entries = <CloudEntry>[];
    while (next != null) {
      final response = await _client.get(next, headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('OneDrive list failed (${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map;
      for (final raw in (data['value'] as List? ?? const [])) {
        final item = raw as Map;
        final isFolder = item['folder'] != null;
        // Skip anything that's neither (e.g. OneNote packages).
        if (!isFolder && item['file'] == null) continue;
        entries.add(
          CloudEntry(
            id: item['id'] as String,
            name: item['name'] as String,
            isDirectory: isFolder,
            size: isFolder ? null : (item['size'] as num?)?.toInt(),
          ),
        );
      }
      final link = data['@odata.nextLink'];
      next = link is String ? Uri.parse(link) : null;
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Fetched fresh at pick time rather than kept from the listing, since
  /// these URLs only stay valid for a short while.
  @override
  Future<String> downloadUrl(CloudEntry file) async {
    final response = await _client.get(
      Uri.https(
        _graphHost,
        '/v1.0/me/drive/items/${Uri.encodeComponent(file.id)}',
      ),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('OneDrive item lookup failed (${response.statusCode})');
    }
    final url =
        (jsonDecode(response.body) as Map)['@microsoft.graph.downloadUrl'];
    if (url is! String) throw Exception('OneDrive gave no download link');
    return url;
  }
}
