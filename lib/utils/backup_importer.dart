import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/bookmark_store.dart';
import '../data/folder_store.dart';
import '../data/highlight_store.dart';
import '../data/library_store.dart';
import '../l10n/strings.dart';
import '../models/book.dart';
import '../models/bookmark.dart';
import '../models/folder.dart';
import '../models/highlight.dart';

class BackupRestoreSummary {
  final int books;
  final int folders;
  final int bookmarks;
  final int highlights;

  const BackupRestoreSummary({
    required this.books,
    required this.folders,
    required this.bookmarks,
    required this.highlights,
  });
}

/// Restores a zip built by [BackupExporter]. Every book/folder/bookmark/
/// highlight in the backup is added to the current library, merging by id
/// — a matching id overwrites (harmless: restoring the same backup twice,
/// or onto the device that made it, is idempotent), and everything else is
/// added alongside whatever's already there. Nothing already in the
/// library is ever deleted by a restore.
class BackupImporter {
  static Future<BackupRestoreSummary> restore(Uint8List zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw FormatException(tr('backup_invalid'));
    }

    final manifestFile = archive.files.firstWhere(
      (f) => f.name == 'manifest.json',
      orElse: () => throw FormatException(tr('backup_invalid')),
    );
    final Map manifest;
    try {
      manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map;
    } catch (_) {
      throw FormatException(tr('backup_invalid'));
    }
    if (manifest['version'] != 1) {
      throw FormatException(tr('backup_unsupported_version'));
    }

    final bookBytesById = <String, List<int>>{
      for (final f in archive.files)
        if (f.isFile && f.name.startsWith('books/') && f.name.endsWith('.bin'))
          f.name.substring('books/'.length, f.name.length - '.bin'.length):
              f.content as List<int>,
    };

    var bookCount = 0;
    for (final raw in (manifest['books'] as List? ?? const [])) {
      final map = raw as Map;
      final id = map['id'] as String;
      final bytes = bookBytesById[id];
      // A manifest entry with no matching books/<id>.bin is a corrupt
      // backup — skip just that book rather than failing the whole
      // restore, since everything else in the file is likely still fine.
      if (bytes == null) continue;
      final lastOpenedRaw = map['lastOpenedAt'] as String?;
      await LibraryStore.save(
        Book(
          id: id,
          name: map['name'] as String,
          format: BookFormat.values.byName(map['format'] as String),
          bytes: Uint8List.fromList(bytes),
          addedAt: DateTime.parse(map['addedAt'] as String),
          lastOpenedAt: lastOpenedRaw != null
              ? DateTime.parse(lastOpenedRaw)
              : null,
          position: map['position'],
          progress: (map['progress'] as num?)?.toDouble(),
          folderId: map['folderId'] as String?,
        ),
      );
      bookCount++;
    }

    var folderCount = 0;
    for (final raw in (manifest['folders'] as List? ?? const [])) {
      final map = raw as Map;
      await FolderStore.add(Folder.fromMap(map['id'] as String, map));
      folderCount++;
    }

    var bookmarkCount = 0;
    for (final raw in (manifest['bookmarks'] as List? ?? const [])) {
      final map = raw as Map;
      await BookmarkStore.add(Bookmark.fromMap(map['id'] as String, map));
      bookmarkCount++;
    }

    var highlightCount = 0;
    for (final raw in (manifest['highlights'] as List? ?? const [])) {
      final map = raw as Map;
      await HighlightStore.add(Highlight.fromMap(map['id'] as String, map));
      highlightCount++;
    }

    return BackupRestoreSummary(
      books: bookCount,
      folders: folderCount,
      bookmarks: bookmarkCount,
      highlights: highlightCount,
    );
  }
}
