import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/bookmark_store.dart';
import '../data/folder_store.dart';
import '../data/highlight_store.dart';
import '../data/library_store.dart';

/// Bundles the whole library -- every book's bytes (notes included),
/// folders, bookmarks and highlights -- into a single zip: `manifest.json`
/// (everything but the raw book bytes) plus one `books/<id>.bin` per book.
class BackupExporter {
  static Uint8List build() {
    final books = LibraryStore.loadAll();
    final folders = FolderStore.loadAll();
    final bookmarks = BookmarkStore.loadAll();
    final highlights = HighlightStore.loadAll();

    final manifest = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'folders': [
        for (final f in folders)
          {'id': f.id, 'name': f.name, 'createdAt': f.createdAt.toIso8601String()},
      ],
      'books': [
        for (final b in books)
          {
            'id': b.id,
            'name': b.name,
            'format': b.format.name,
            'addedAt': b.addedAt.toIso8601String(),
            'lastOpenedAt': b.lastOpenedAt?.toIso8601String(),
            'position': b.position,
            'progress': b.progress,
            'folderId': b.folderId,
          },
      ],
      'bookmarks': [
        for (final bm in bookmarks)
          {
            'id': bm.id,
            'bookId': bm.bookId,
            'position': bm.position,
            'label': bm.label,
            'createdAt': bm.createdAt.toIso8601String(),
          },
      ],
      'highlights': [
        for (final h in highlights)
          {
            'id': h.id,
            'bookId': h.bookId,
            'chunkIndex': h.chunkIndex,
            'start': h.start,
            'end': h.end,
            'text': h.text,
            'color': h.color.toARGB32(),
            'createdAt': h.createdAt.toIso8601String(),
          },
      ],
    };

    final archive = Archive();
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    for (final b in books) {
      archive.addFile(
        ArchiveFile('books/${b.id}.bin', b.bytes.length, b.bytes),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// `moon_atelier_backup_2026-09-09.zip`
  static String suggestedFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'moon_atelier_backup_${now.year}-${two(now.month)}-${two(now.day)}.zip';
  }
}
