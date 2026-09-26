import 'dart:typed_data';

import 'package:ebk/utils/wifi_transfer_server_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Exercises the real HTTP round trip (not just the handler in isolation),
/// since the page's <form action="upload"> and the server's routing have to
/// actually agree once the browser resolves that relative URL against
/// whatever address [WifiTransferServer.start] hands out -- exactly the
/// kind of mismatch that doesn't show up in a unit test that calls the
/// request handler directly with a hand-built URL.
void main() {
  test(
    'the served upload form posts to a path the server actually handles',
    () async {
      final server = WifiTransferServer();
      final address = await server.start();
      expect(address, isNotNull);
      addTearDown(server.stop);

      final getResponse = await http.get(Uri.parse(address!));
      expect(getResponse.statusCode, 200);
      expect(getResponse.body, contains('<form'));

      // Resolve the form's "action" attribute exactly the way a browser
      // would: relative to the page's own URL.
      final actionMatch = RegExp(r'action="([^"]+)"')
          .firstMatch(getResponse.body)!;
      final uploadUri = Uri.parse(address).resolve(actionMatch.group(1)!);

      final request = http.MultipartRequest('POST', uploadUri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            Uint8List.fromList('hello'.codeUnits),
            filename: 'note.txt',
          ),
        );
      final streamedResponse = await request.send();
      expect(streamedResponse.statusCode, 200);

      final picked = await server.received.first.timeout(
        const Duration(seconds: 5),
      );
      expect(picked.name, 'note.txt');
      expect(String.fromCharCodes(picked.bytes), 'hello');
    },
  );

  test('keeps accepting files until stopped', () async {
    final server = WifiTransferServer();
    final address = await server.start();
    expect(address, isNotNull);
    final names = <String>[];
    final sub = server.received.listen((f) => names.add(f.name));
    addTearDown(sub.cancel);
    addTearDown(server.stop);

    for (final name in ['a.txt', 'b.epub']) {
      final request =
          http.MultipartRequest('POST', Uri.parse('$address/upload'))
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                Uint8List.fromList([1, 2, 3]),
                filename: name,
              ),
            );
      expect((await request.send()).statusCode, 200);
    }
    await Future<void>.delayed(Duration.zero);
    expect(names, ['a.txt', 'b.epub']);
  });
}
