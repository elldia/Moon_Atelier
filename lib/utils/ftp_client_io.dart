import 'dart:typed_data';

import 'package:ftpconnect/ftpconnect.dart';

/// Native (Android/iOS/desktop) FTP support via `package:ftpconnect`, which
/// opens raw sockets through `dart:io` and so has no web implementation —
/// see `ftp_client_web.dart` for the stub used there.
const bool isFtpAvailable = true;

class FtpEntry {
  final String name;
  final bool isDirectory;
  final int? size;

  const FtpEntry({required this.name, required this.isDirectory, this.size});
}

/// A connected FTP session, wrapping [FTPConnect] with the smaller surface
/// the file-import browser dialog actually needs.
class FtpSession {
  final FTPConnect _connect;

  FtpSession._(this._connect);

  static Future<FtpSession> connect({
    required String host,
    int port = 21,
    String user = '',
    String pass = '',
  }) async {
    final connect = FTPConnect(
      host,
      port: port,
      user: user.isEmpty ? 'anonymous' : user,
      pass: pass,
      timeout: 15,
    );
    await connect.connect();
    return FtpSession._(connect);
  }

  Future<String> currentPath() => _connect.currentDirectory();

  /// Lists the current directory, directories first, both groups
  /// case-insensitively alphabetical.
  Future<List<FtpEntry>> list() async {
    final entries = await _connect.listDirectoryContent();
    final result = entries
        .where(
          (e) => e.type == FTPEntryType.dir || e.type == FTPEntryType.file,
        )
        .map(
          (e) => FtpEntry(
            name: e.name,
            isDirectory: e.type == FTPEntryType.dir,
            size: e.size,
          ),
        )
        .toList();
    result.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  Future<bool> changeDirectory(String directory) =>
      _connect.changeDirectory(directory);

  Future<Uint8List> downloadToBytes(String fileName) =>
      _connect.downloadToBytes(fileName);

  Future<void> disconnect() async {
    try {
      await _connect.disconnect();
    } catch (_) {
      // Best-effort cleanup; the socket may already be gone.
    }
  }
}
