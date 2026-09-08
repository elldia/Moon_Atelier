import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Extracts the raw MusicXML markup from either an uncompressed .musicxml
/// file or a compressed .mxl file (a zip container), detected by sniffing
/// the bytes' magic number rather than trusting the file extension.
String extractMusicXmlText(Uint8List bytes) {
  final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  if (!isZip) {
    return utf8.decode(bytes, allowMalformed: true);
  }

  final archive = ZipDecoder().decodeBytes(bytes);

  // The MXL container spec points at the root score file via
  // META-INF/container.xml; fall back to the first non-metadata XML entry
  // if that's missing or malformed.
  ArchiveFile? rootFile;
  for (final f in archive.files) {
    if (f.name == 'META-INF/container.xml' && f.content != null) {
      try {
        final doc = XmlDocument.parse(
          utf8.decode(f.content as List<int>, allowMalformed: true),
        );
        final path = doc
            .findAllElements('rootfile')
            .first
            .getAttribute('full-path');
        if (path != null) {
          for (final candidate in archive.files) {
            if (candidate.name == path) {
              rootFile = candidate;
              break;
            }
          }
        }
      } catch (_) {
        // Fall through to the heuristic below.
      }
      break;
    }
  }

  rootFile ??= archive.files.firstWhere(
    (f) =>
        f.isFile &&
        f.name != 'META-INF/container.xml' &&
        (f.name.toLowerCase().endsWith('.xml') ||
            f.name.toLowerCase().endsWith('.musicxml')),
    orElse: () =>
        throw const FormatException('No MusicXML entry found in .mxl file.'),
  );

  return utf8.decode(rootFile.content as List<int>, allowMalformed: true);
}
