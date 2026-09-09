import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Native (Android/iOS/desktop) counterpart of the web build's
/// `pdf_text_extractor_web.dart`. `pdfx` (used for rendering, see
/// pdf_viewer_screen.dart) has no text-extraction API on native platforms,
/// so this opens a second, independent PDFium document from the same bytes
/// via `pdfrx` purely for text extraction, without touching pdfx's
/// internals -- mirroring the web build's pdf.js side-document approach.
class PdfTextExtractor {
  PdfTextExtractor(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  PdfDocument? _doc;
  final Map<int, String> _cache = {};

  Future<void> _ensureOpen() async {
    if (_doc != null) return;
    await pdfrxFlutterInitialize();
    _doc = await PdfDocument.openData(_bytes);
  }

  /// 1-based [pageNumber], matching pdfx's own page numbering.
  Future<String> extractPageText(int pageNumber) async {
    final cached = _cache[pageNumber];
    if (cached != null) return cached;
    await _ensureOpen();
    final page = _doc!.pages[pageNumber - 1];
    final text = (await page.loadStructuredText()).fullText;
    _cache[pageNumber] = text;
    return text;
  }

  void dispose() {
    _doc?.dispose();
    _doc = null;
    _cache.clear();
  }
}
