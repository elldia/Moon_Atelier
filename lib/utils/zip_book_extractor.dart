import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/book.dart';
import 'text_decoder.dart';

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
    final name = _recoverZipEntryName(file.name);
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0) continue;
    final ext = name.substring(dotIndex + 1);
    final format = Book.formatFromExtension(ext);
    if (format == null) continue;
    final content = file.content;
    if (content is! List<int>) continue;
    return ZipExtractedFile(
      name: name.split('/').last,
      format: format,
      bytes: Uint8List.fromList(content),
    );
  }
  return null;
}

/// The `archive` package always assumes ZIP entry filenames are UTF-8; for a
/// non-UTF8-flagged entry (common from older/Korean zip tools that write
/// filenames in the system codepage, e.g. CP949, instead of UTF-8) that
/// assumption fails, and it silently falls back to treating each raw byte as
/// its own code point — a lossless byte-preserving passthrough, not a
/// correct decode. That shows up as Korean filenames turning into
/// Latin-looking mojibake while ASCII names (and correctly UTF-8-flagged
/// ones) are unaffected — matching exactly what was reported.
///
/// Recover from that: a name that went through the byte-preserving
/// fallback has every code unit in the single-byte range (0-255), so
/// converting it back to raw bytes and re-decoding (UTF-8, then CP949) is
/// safe and lossless. A name that decoded correctly the first time already
/// contains real multi-byte code points (Hangul is U+AC00+) and is left
/// untouched.
String _recoverZipEntryName(String name) {
  if (name.codeUnits.any((c) => c > 0xFF)) return name;
  return decodeTextBytes(Uint8List.fromList(name.codeUnits));
}
