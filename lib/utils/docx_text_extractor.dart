import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../l10n/strings.dart';

/// Extracts plain text from a .docx file's bytes.
///
/// A .docx is a zip archive; the visible text lives in
/// `word/document.xml` as `<w:t>` runs grouped into `<w:p>` paragraphs.
/// Tabs (`<w:tab/>`) and manual line breaks (`<w:br/>`/`<w:cr/>`) are
/// self-closing siblings of `<w:t>` with no text content of their own, so
/// they're walked in document order alongside the text runs rather than
/// just collected via `<w:t>` alone -- otherwise a table cell's tab or a
/// mid-paragraph line break silently vanishes and adjacent words fuse
/// together (e.g. "Column1\tColumn2" becomes "Column1Column2").
String extractDocxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final documentFile = archive.files.firstWhere(
    (f) => f.name == 'word/document.xml',
    orElse: () => throw FormatException(tr('docx_missing_document_xml')),
  );

  final xmlContent = utf8.decode(documentFile.content as List<int>);
  final document = XmlDocument.parse(xmlContent);

  final paragraphs = document.findAllElements('w:p').map((paragraph) {
    final buffer = StringBuffer();
    for (final el in paragraph.descendantElements) {
      switch (el.name.local) {
        case 't':
          buffer.write(el.innerText);
        case 'tab':
          buffer.write('\t');
        case 'br':
        case 'cr':
          buffer.write('\n');
      }
    }
    return buffer.toString();
  });

  return paragraphs.join('\n').trim();
}
