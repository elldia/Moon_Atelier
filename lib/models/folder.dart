import 'book.dart';

/// A flat (non-nested) folder used to organize books in the library. Each
/// folder belongs to one library — the e-book reader's or the comic
/// viewer's — and only shows up there.
class Folder {
  final String id;
  final String name;
  final DateTime createdAt;
  final BookKind kind;

  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.kind,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'kind': kind.name,
  };

  /// Folders saved before [kind] existed were shared by both libraries;
  /// they read back as e-book folders here, and
  /// [FolderStore.assignLegacyKinds] sorts them out properly on startup.
  factory Folder.fromMap(String id, Map raw) => Folder(
    id: id,
    name: raw['name'] as String,
    createdAt: DateTime.parse(raw['createdAt'] as String),
    kind: BookKind.values.firstWhere(
      (k) => k.name == raw['kind'],
      orElse: () => BookKind.ebook,
    ),
  );
}
