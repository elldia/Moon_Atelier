import 'dart:typed_data';

import 'package:epubx/epubx.dart' as epubx;
import 'package:html/parser.dart' as html_parser;

/// Extracts plain text per chapter/subchapter from an EPUB, for content
/// search and text-to-speech. epub_view only exposes rendering (and a
/// flattened *paragraph* index for scroll position) — not raw chapter
/// text — so this independently re-parses the same bytes with epubx.
///
/// The flattening here must exactly match EpubController.tableOfContents()'s
/// order (top-level chapters, each immediately followed by its direct
/// subchapters — not recursed deeper) so index i here lines up with
/// tableOfContents()[i] and its startIndex can be used as the jump target.
class EpubTextExtractor {
  EpubTextExtractor(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  List<String>? _chapterTexts;

  Future<List<String>> chapterTexts() async {
    final cached = _chapterTexts;
    if (cached != null) return cached;
    final book = await epubx.EpubReader.readBook(_bytes);
    final texts = <String>[];
    for (final chapter in book.Chapters ?? const <epubx.EpubChapter>[]) {
      texts.add(_plainText(chapter.HtmlContent));
      for (final sub in chapter.SubChapters ?? const <epubx.EpubChapter>[]) {
        texts.add(_plainText(sub.HtmlContent));
      }
    }
    _chapterTexts = texts;
    return texts;
  }

  String _plainText(String? html) {
    if (html == null || html.isEmpty) return '';
    return html_parser.parse(html).body?.text ?? '';
  }
}
