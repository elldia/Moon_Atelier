import 'dart:js_interop';
import 'dart:typed_data';

/// Extracts plain text per page from a PDF, for content search and
/// text-to-speech — neither pdfx nor the vendored patch expose this (pdfx
/// only renders pages to images via pdf.js). pdf.js itself supports text
/// extraction (`page.getTextContent()`), and is already loaded globally as
/// `window.pdfjsLib` by pdfx's own web bootstrapping (see web/index.html),
/// so this opens a second, independent pdf.js document from the same bytes
/// purely for text extraction, without touching pdfx's internals.
class PdfTextExtractor {
  PdfTextExtractor(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  _PdfjsDocument? _doc;
  final Map<int, String> _cache = {};

  Future<void> _ensureOpen() async {
    if (_doc != null) return;
    final lib = _pdfjsLib;
    if (lib == null) throw Exception('pdfjsLib not loaded');
    final options = _GetDocumentOptions(data: _bytes.buffer.toJS);
    _doc = await lib.getDocument(options).promise.toDart;
  }

  /// 1-based [pageNumber], matching pdfx's own page numbering.
  Future<String> extractPageText(int pageNumber) async {
    final cached = _cache[pageNumber];
    if (cached != null) return cached;
    await _ensureOpen();
    final page = await _doc!.getPage(pageNumber).toDart;
    final content = await page.getTextContent().toDart;
    final buf = StringBuffer();
    for (final item in content.items.toDart) {
      buf.write(item.str);
      buf.write(item.hasEOL ? '\n' : ' ');
    }
    final text = buf.toString();
    _cache[pageNumber] = text;
    return text;
  }

  void dispose() {
    _doc?.destroy();
    _doc = null;
    _cache.clear();
  }
}

@JS('pdfjsLib')
external _PdfjsLib? get _pdfjsLib;

extension type _PdfjsLib._(JSObject _) implements JSObject {
  external _PdfjsDocumentTask getDocument(_GetDocumentOptions options);
}

extension type _GetDocumentOptions._(JSObject _) implements JSObject {
  external factory _GetDocumentOptions({required JSArrayBuffer data});
}

extension type _PdfjsDocumentTask._(JSObject _) implements JSObject {
  external JSPromise<_PdfjsDocument> get promise;
}

extension type _PdfjsDocument._(JSObject _) implements JSObject {
  external JSPromise<_PdfjsPage> getPage(int pageNumber);
  external void destroy();
}

extension type _PdfjsPage._(JSObject _) implements JSObject {
  external JSPromise<_PdfjsTextContent> getTextContent();
}

extension type _PdfjsTextContent._(JSObject _) implements JSObject {
  external JSArray<_PdfjsTextItem> get items;
}

extension type _PdfjsTextItem._(JSObject _) implements JSObject {
  external String get str;
  external bool get hasEOL;
}
