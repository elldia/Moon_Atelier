import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../l10n/strings.dart';

/// Extracts plain text from a .docx file's bytes.
///
/// A .docx is a zip archive; the visible text lives in
/// `word/document.xml` as `<w:t>` runs grouped into `<w:p>` paragraphs.
String extractDocxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final documentFile = archive.files.firstWhere(
    (f) => f.name == 'word/document.xml',
    orElse: () => throw FormatException(tr('docx_missing_document_xml')),
  );

  final xmlContent = utf8.decode(documentFile.content as List<int>);
  final document = XmlDocument.parse(xmlContent);

  final paragraphs = document.findAllElements('w:p').map((paragraph) {
    return paragraph.findAllElements('w:t').map((t) => t.innerText).join();
  });

  return paragraphs.join('\n').trim();
}
