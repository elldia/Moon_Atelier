import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';

/// Native-only: binds a real `dart:io` [HttpServer], which has no web
/// equivalent — see `wifi_transfer_server_web.dart` for the stub used there.
const bool isWifiTransferAvailable = true;

class WifiTransferPickedFile {
  final String name;
  final Uint8List bytes;

  const WifiTransferPickedFile({required this.name, required this.bytes});
}

/// A short-lived local HTTP server that shows a one-file upload form at a
/// random path (so a stray port scan on the LAN can't stumble onto it) and
/// resolves [waitForFile] once something is uploaded.
class WifiTransferServer {
  HttpServer? _server;
  final _completer = Completer<WifiTransferPickedFile>();
  late final String _token;

  /// Starts the server and returns the URL to open on the sending device,
  /// or null if no local network address could be found (e.g. no Wi-Fi).
  Future<String?> start() async {
    final ip = await _localIPv4();
    if (ip == null) return null;
    _token = _randomToken();
    final handler = const Pipeline().addHandler(_handleRequest);
    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _server = server;
    return 'http://$ip:${server.port}/$_token';
  }

  Future<Response> _handleRequest(Request request) async {
    final segments = request.url.pathSegments;
    if (segments.isEmpty || segments.first != _token) {
      return Response.notFound('Not found');
    }
    if (request.method == 'GET' && segments.length == 1) {
      return Response.ok(
        _uploadPageHtml,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }
    if (request.method == 'POST' &&
        segments.length == 2 &&
        segments[1] == 'upload') {
      final form = request.formData();
      if (form == null) {
        return Response(400, body: 'Not a multipart form');
      }
      await for (final field in form.formData) {
        final filename = field.filename;
        if (filename != null && filename.isNotEmpty) {
          final bytes = await field.part.readBytes();
          if (!_completer.isCompleted) {
            _completer.complete(
              WifiTransferPickedFile(name: filename, bytes: bytes),
            );
          }
          return Response.ok(
            _successPageHtml,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
      }
      return Response(400, body: 'No file field found');
    }
    return Response.notFound('Not found');
  }

  Future<WifiTransferPickedFile> waitForFile() => _completer.future;

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

String _randomToken() {
  final rand = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
}

Future<String?> _localIPv4() async {
  try {
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    )) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {
    // Falls through to null below.
  }
  return null;
}

const _uploadPageHtml = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ebk 파일 전송</title>
<style>
  body { font-family: sans-serif; max-width: 420px; margin: 60px auto; padding: 0 16px; text-align: center; }
  input[type=file] { margin: 20px 0; }
  button { padding: 10px 24px; font-size: 16px; }
</style>
</head>
<body>
  <h2>ebk로 파일 보내기</h2>
  <form method="POST" action="upload" enctype="multipart/form-data">
    <input type="file" name="file" required>
    <br>
    <button type="submit">전송</button>
  </form>
</body>
</html>
''';

const _successPageHtml = '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>전송 완료</title></head>
<body style="font-family: sans-serif; text-align: center; margin-top: 80px;">
  <h2>전송 완료!</h2>
  <p>폰 화면에서 확인해 주세요.</p>
</body>
</html>
''';
