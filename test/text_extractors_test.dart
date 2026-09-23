import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ebk/utils/docx_text_extractor.dart';
import 'package:ebk/utils/hwpx_text_extractor.dart';
import 'package:ebk/utils/rtf_text_extractor.dart';

Uint8List _zipOf(String path, String xml) {
  final bytes = utf8.encode(xml);
  final archive = Archive();
  archive.addFile(ArchiveFile(path, bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

// Builds an RTF "\uNNNN" control word via concatenation rather than a
// literal escape sequence in this source file, so nothing between here and
// disk can mistake a literal `\u` + 4 hex digits for a Dart/JSON unicode
// escape and "helpfully" decode it before the RTF parser ever sees it.
String _rtfU(int code) => '${_bs}u$code';
final _bs = String.fromCharCode(0x5c);

void main() {
  group('extractDocxText', () {
    test('keeps tabs and manual line breaks instead of fusing words', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Column1</w:t></w:r><w:r><w:tab/></w:r><w:r><w:t>Column2</w:t></w:r></w:p>
    <w:p><w:r><w:t>Line1</w:t></w:r><w:r><w:br/></w:r><w:r><w:t>Line2</w:t></w:r></w:p>
  </w:body>
</w:document>''';
      final text = extractDocxText(_zipOf('word/document.xml', xml));
      expect(text, 'Column1\tColumn2\nLine1\nLine2');
    });
  });

  group('extractHwpxText', () {
    test('keeps tabs and line breaks instead of fusing words', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<hp:sec xmlns:hp="http://www.hancom.co.kr/hwpml/2011/paragraph">
  <hp:p><hp:run><hp:t>Column1</hp:t><hp:tab/><hp:t>Column2</hp:t></hp:run></hp:p>
  <hp:p><hp:run><hp:t>Line1</hp:t><hp:lineBreak/><hp:t>Line2</hp:t></hp:run></hp:p>
</hp:sec>''';
      final text = extractHwpxText(_zipOf('Contents/section0.xml', xml));
      expect(text, 'Column1\tColumn2\nLine1\nLine2');
    });
  });

  group('extractRtfText', () {
    test(r'\uc and \ansicpg revert once their group closes', () {
      // Inside the nested group, \uc0 means \u escapes have no fallback
      // byte following them; outside, back at the default \uc1, \u escapes
      // have exactly one fallback byte that must be skipped. If \uc leaked
      // out of the group as 0, the trailing '?' below would wrongly survive
      // into the extracted text.
      final rtf =
          '{${_bs}rtf1${_bs}ansicpg1252 Start {${_bs}uc0${_rtfU(9731)}} '
          'Mid${_rtfU(9733)}?End}';
      final text = extractRtfText(Uint8List.fromList(latin1.encode(rtf)));
      expect(text, isNot(contains('?')));
      expect(text, contains(String.fromCharCode(9731))); // snowman
      expect(text, contains(String.fromCharCode(9733))); // star
    });

    test('\\tab and \\par produce literal whitespace', () {
      // The single space after each control word is the RTF delimiter that
      // disambiguates it from the following letter -- it's consumed, not
      // emitted, so the extracted text has no extra spaces of its own.
      final rtf = '{${_bs}rtf1 A${_bs}tab B${_bs}par C}';
      final text = extractRtfText(Uint8List.fromList(latin1.encode(rtf)));
      expect(text, 'A\tB\nC');
    });
  });
}
