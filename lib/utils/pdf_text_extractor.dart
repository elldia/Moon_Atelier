// Picks the right `PdfTextExtractor` implementation for the current
// platform at compile time: pdf.js (already loaded for `pdfx`'s own web
// rendering) on web, a second `pdfrx`/PDFium document on native platforms
// -- see pdf_text_extractor_web.dart / pdf_text_extractor_io.dart.
export 'pdf_text_extractor_io.dart'
    if (dart.library.js_interop) 'pdf_text_extractor_web.dart';
