/// A saved reading position for a book.
///
/// [position] mirrors [Book.position]'s per-format meaning: a scroll offset
/// (txt/docx/rtf), an EPUB CFI string, or a 1-based PDF page number.
class Bookmark {
  final String id;
  final String bookId;
  final Object position;
  final String label;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.bookId,
    required this.position,
    required this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'bookId': bookId,
    'position': position,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Bookmark.fromMap(String id, Map raw) => Bookmark(
    id: id,
    bookId: raw['bookId'] as String,
    position: raw['position'] as Object,
    label: raw['label'] as String,
    createdAt: DateTime.parse(raw['createdAt'] as String),
  );
}
