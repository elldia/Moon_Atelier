import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../l10n/strings.dart';

/// Extracts plain text from a .hwpx file's bytes.
///
/// A .hwpx (the open, XML-based HWP format used by 한글 since 2014 — not
/// the older binary .hwp format, which this does not support) is a zip
/// archive whose visible text lives across one or more
/// `Contents/section*.xml` files, each holding `<hp:p>` paragraphs of
/// `<hp:t>` text runs. Elements are matched by local name regardless of
/// namespace prefix, since real-world files consistently use `hp:` but
/// nothing guarantees it.
String extractHwpxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final sectionFiles =
      archive.files
          .where(
            (f) =>
                f.isFile &&
                RegExp(r'^Contents/section\d+\.xml$').hasMatch(f.name),
          )
          .toList()
        ..sort(
          (a, b) => _sectionIndex(a.name).compareTo(_sectionIndex(b.name)),
        );

  if (sectionFiles.isEmpty) {
    throw FormatException(tr('hwpx_missing_sections'));
  }

  final sections = sectionFiles.map((file) {
    final xmlContent = utf8.decode(file.content as List<int>);
    final document = XmlDocument.parse(xmlContent);
    final paragraphs = document.findAllElements('p', namespace: '*').map((
      paragraph,
    ) {
      // <hp:tab/> and <hp:lineBreak/> are self-closing siblings of <hp:t>
      // with no text content of their own -- collecting only <hp:t> runs
      // silently drops every tab/line-break, fusing adjacent words together
      // (e.g. a table cell's "Column1\tColumn2" becomes "Column1Column2").
      final buffer = StringBuffer();
      for (final el in paragraph.descendantElements) {
        switch (el.name.local) {
          case 't':
            buffer.write(el.innerText);
          case 'tab':
            buffer.write('\t');
          case 'lineBreak':
            buffer.write('\n');
        }
      }
      return buffer.toString();
    });
    return paragraphs.join('\n');
  });

  return sections.join('\n').trim();
}

int _sectionIndex(String path) =>
    int.parse(RegExp(r'\d+').firstMatch(path)!.group(0)!);
