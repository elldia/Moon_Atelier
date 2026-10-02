import 'dart:convert';

import 'package:ebk/utils/onedrive_picker.dart';
import 'package:ebk/utils/pkce.dart';
import 'package:ebk/widgets/cloud_browser_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('the sign-in URL matches the app registration', () {
    final url = oneDriveAuthorizeUrl('challenge123');
    expect(url.host, 'login.microsoftonline.com');
    expect(url.path, '/common/oauth2/v2.0/authorize');
    expect(url.queryParameters, {
      'client_id': '2a74492a-b511-46d8-bd7a-8c6603f9f8d3',
      'response_type': 'code',
      'redirect_uri': 'moonatelier://onedrive-auth',
      'response_mode': 'query',
      'scope': 'Files.Read',
      'code_challenge': 'challenge123',
      'code_challenge_method': 'S256',
    });
  });

  test('PKCE challenge is the RFC 7636 S256 of the verifier', () {
    // The RFC's own Appendix B example.
    expect(
      codeChallengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
    final verifier = generateCodeVerifier();
    expect(verifier.length, 64);
    expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(verifier), isTrue);
  });

  test('exchanges the code for a token with the PKCE verifier', () async {
    late Map<String, String> sent;
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://login.microsoftonline.com/common/oauth2/v2.0/token',
      );
      sent = Uri.splitQueryString(request.body);
      return http.Response(jsonEncode({'access_token': 'tok'}), 200);
    });
    final session = await OneDriveSession.exchangeCode(
      code: 'the-code',
      verifier: 'the-verifier',
      client: client,
    );
    expect(session, isNotNull);
    expect(sent, {
      'client_id': '2a74492a-b511-46d8-bd7a-8c6603f9f8d3',
      'grant_type': 'authorization_code',
      'scope': 'Files.Read',
      'code': 'the-code',
      'redirect_uri': 'moonatelier://onedrive-auth',
      'code_verifier': 'the-verifier',
    });
  });

  test('a rejected code signs nobody in', () async {
    final client = MockClient(
      (_) async => http.Response('{"error":"invalid_grant"}', 400),
    );
    expect(
      await OneDriveSession.exchangeCode(
        code: 'c',
        verifier: 'v',
        client: client,
      ),
      isNull,
    );
  });

  test('lists a folder across pages, folders first, alphabetically', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      expect(request.headers['Authorization'], 'Bearer tok');
      if (request.url.queryParameters['page'] != '2') {
        return http.Response(
          jsonEncode({
            'value': [
              {'id': 'f2', 'name': 'b.epub', 'size': 20, 'file': {}},
              {
                'id': 'd1',
                'name': 'Zeta',
                'folder': {'childCount': 1},
              },
              {'id': 'x', 'name': 'Notebook', 'package': {}},
            ],
            '@odata.nextLink': 'https://graph.microsoft.com/v1.0/me/drive/root/children?page=2',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'value': [
            {'id': 'f1', 'name': 'A.txt', 'size': 10, 'file': {}},
            {'id': 'd2', 'name': 'alpha', 'folder': {}},
          ],
        }),
        200,
      );
    });
    final session = OneDriveSession('tok', client: client);
    final entries = await session.list(null);
    expect(
      [for (final e in entries) e.name],
      ['alpha', 'Zeta', 'A.txt', 'b.epub'],
    );
    expect(entries.first.isDirectory, isTrue);
    expect(entries.last.size, 20);
    expect(requests, hasLength(2));
  });

  test('lists a subfolder by its item id', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(jsonEncode({'value': []}), 200);
    });
    await OneDriveSession('tok', client: client).list('ABC!123');
    expect(requested.path, '/v1.0/me/drive/items/ABC!123/children');
  });

  test('a failed listing reports an error', () async {
    final client = MockClient((_) async => http.Response('', 401));
    expect(OneDriveSession('tok', client: client).list(null), throwsException);
  });

  test('fetches a fresh download link when a file is picked', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1.0/me/drive/items/f1');
      return http.Response(
        jsonEncode({
          'id': 'f1',
          '@microsoft.graph.downloadUrl': 'https://dl.example/f1',
        }),
        200,
      );
    });
    final url = await OneDriveSession('tok', client: client).downloadUrl(
      const CloudEntry(id: 'f1', name: 'A.txt', isDirectory: false),
    );
    expect(url, 'https://dl.example/f1');
  });
}
