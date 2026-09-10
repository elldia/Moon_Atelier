import 'dart:typed_data';

/// Web stub: this feature binds a real `dart:io` [HttpServer] to listen on
/// the local network, which a browser sandbox can't do — native-only. See
/// `wifi_transfer_server_io.dart` for the real implementation.
const bool isWifiTransferAvailable = false;

class WifiTransferPickedFile {
  final String name;
  final Uint8List bytes;

  const WifiTransferPickedFile({required this.name, required this.bytes});
}

class WifiTransferServer {
  Future<String?> start() =>
      throw UnsupportedError('Wi-Fi transfer is not supported on the web build.');

  Future<WifiTransferPickedFile> waitForFile() =>
      throw UnsupportedError('web stub');

  Future<void> stop() => throw UnsupportedError('web stub');
}
