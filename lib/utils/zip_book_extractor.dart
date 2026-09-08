import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/book.dart';

class ZipExtractedFile {
  final String name;
  final BookFormat format;
  final Uint8List bytes;

  const ZipExtractedFile({
    required this.name,
    required this.format,
    required this.bytes,
  });
}

/// Looks inside a .zip archive for the first entry whose extension matches
/// a supported book format, and returns it extracted — or null if none
/// found. Lets a user pick a plain .zip (e.g. one they made themselves, or
/// received from somewhere) and have the book inside it opened directly
/// instead of failing with "unsupported format".
ZipExtractedFile? findSupportedFileInZip(Uint8List zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  for (final file in archive.files) {
    if (!file.isFile) continue;
    final dotIndex = file.name.lastIndexOf('.');
    if (dotIndex < 0) continue;
    final ext = file.name.substring(dotIndex + 1);
    final format = Book.formatFromExtension(ext);
    if (format == null) continue;
    final content = file.content;
    if (content is! List<int>) continue;
    return ZipExtractedFile(
      name: file.name.split('/').last,
      format: format,
      bytes: Uint8List.fromList(content),
    );
  }
  return null;
}
