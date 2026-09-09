import 'dart:typed_data';

enum BookFormat { epub, pdf, txt, docx, rtf, musicXml, note }

class Book {
  final String id;
  final String name;
  final BookFormat format;
  final Uint8List bytes;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  /// Last reading position, meaning depends on [format]:
  /// - epub: an EPUB CFI string
  /// - pdf: 1-based page number
  /// - txt / docx / rtf: vertical scroll offset in pixels
  final Object? position;

  /// How far through the book the reader has gotten, 0.0-1.0. Reported by
  /// each viewer alongside [position] so the library list can show a
  /// progress percentage without re-opening/re-parsing the book.
  final double? progress;

  /// The folder this book is filed under, or null for the library root.
  final String? folderId;

  const Book({
    required this.id,
    required this.name,
    required this.format,
    required this.bytes,
    required this.addedAt,
    this.lastOpenedAt,
    this.position,
    this.progress,
    this.folderId,
  });

  Book copyWith({
    String? name,
    Uint8List? bytes,
    DateTime? lastOpenedAt,
    Object? position,
    double? progress,
    String? folderId,
    bool moveToRoot = false,
  }) {
    return Book(
      id: id,
      name: name ?? this.name,
      format: format,
      bytes: bytes ?? this.bytes,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      position: position ?? this.position,
      progress: progress ?? this.progress,
      folderId: moveToRoot ? null : (folderId ?? this.folderId),
    );
  }

  static BookFormat? formatFromExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'epub':
        return BookFormat.epub;
      case 'pdf':
        return BookFormat.pdf;
      case 'txt':
        return BookFormat.txt;
      case 'docx':
        return BookFormat.docx;
      case 'rtf':
        return BookFormat.rtf;
      case 'musicxml':
      case 'mxl':
        return BookFormat.musicXml;
      default:
        return null;
    }
  }
}
