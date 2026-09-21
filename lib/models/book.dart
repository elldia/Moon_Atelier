import 'dart:typed_data';

enum BookFormat { epub, pdf, txt, docx, rtf, musicXml, note, comic }

/// Which top-level library a [BookFormat] belongs to — the e-book reader or
/// the comic viewer. Drives which entry screen a book shows up under and
/// which extensions/pickers apply.
enum BookKind { ebook, comic }

extension BookFormatKind on BookFormat {
  BookKind get kind =>
      this == BookFormat.comic ? BookKind.comic : BookKind.ebook;
}

class Book {
  final String id;
  final String name;
  final BookFormat format;
  final Uint8List bytes;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  /// Set whenever the book's own content is edited in place (currently only
  /// [BookFormat.note] supports this). Null means it hasn't been edited
  /// since it was added, so the library list falls back to [addedAt].
  final DateTime? modifiedAt;

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
    this.modifiedAt,
    this.position,
    this.progress,
    this.folderId,
  });

  Book copyWith({
    String? name,
    Uint8List? bytes,
    DateTime? lastOpenedAt,
    DateTime? modifiedAt,
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
      modifiedAt: modifiedAt ?? this.modifiedAt,
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
      case 'cbz':
        return BookFormat.comic;
      default:
        return null;
    }
  }
}
