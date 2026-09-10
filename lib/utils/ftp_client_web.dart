import 'dart:typed_data';

/// Web stub: `package:ftpconnect` opens raw `dart:io` sockets, which don't
/// exist in a browser, so FTP import is native-only. See `ftp_client_io.dart`
/// for the real implementation.
const bool isFtpAvailable = false;

class FtpEntry {
  final String name;
  final bool isDirectory;
  final int? size;

  const FtpEntry({required this.name, required this.isDirectory, this.size});
}

class FtpSession {
  FtpSession._();

  static Future<FtpSession> connect({
    required String host,
    int port = 21,
    String user = '',
    String pass = '',
  }) {
    throw UnsupportedError('FTP import is not supported on the web build.');
  }

  Future<String> currentPath() => throw UnsupportedError('web stub');

  Future<List<FtpEntry>> list() => throw UnsupportedError('web stub');

  Future<bool> changeDirectory(String directory) =>
      throw UnsupportedError('web stub');

  Future<Uint8List> downloadToBytes(String fileName) =>
      throw UnsupportedError('web stub');

  Future<void> disconnect() => throw UnsupportedError('web stub');
}
