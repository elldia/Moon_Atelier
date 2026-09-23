import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ebk/data/bookmark_store.dart';
import 'package:ebk/data/folder_store.dart';
import 'package:ebk/data/highlight_store.dart';
import 'package:ebk/data/library_store.dart';
import 'package:ebk/models/book.dart';
import 'package:ebk/models/bookmark.dart';
import 'package:ebk/models/folder.dart';
import 'package:ebk/models/highlight.dart';
import 'package:ebk/utils/backup_exporter.dart';
import 'package:ebk/utils/backup_importer.dart';

/// Guards the whole-library backup/restore roundtrip -- the same class of
/// bug as the modifiedAt regression this test was written for (a field that
/// exists on a model but silently never makes it into the exported
/// manifest, so it's always lost on restore) is otherwise invisible until
/// someone notices their data changed after restoring a backup.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ebk_backup_test_');
    Hive.init(tempDir.path);
    await LibraryStore.init();
    await BookmarkStore.init();
    await HighlightStore.init();
    await FolderStore.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('export then restore preserves every field, including modifiedAt', () async {
    final addedAt = DateTime.utc(2026, 1, 1, 9);
    final lastOpenedAt = DateTime.utc(2026, 2, 1, 9);
    final modifiedAt = DateTime.utc(2026, 3, 1, 9);

    await FolderStore.add(
      Folder(id: 'folder-1', name: 'My Folder', createdAt: addedAt),
    );
    final book = Book(
      id: 'book-1',
      name: 'My Note',
      format: BookFormat.note,
      bytes: Uint8List.fromList('hello world'.codeUnits),
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt,
      modifiedAt: modifiedAt,
      position: 42,
      progress: 0.5,
      folderId: 'folder-1',
    );
    await LibraryStore.save(book);
    await BookmarkStore.add(
      Bookmark(
        id: 'bm-1',
        bookId: 'book-1',
        position: 42,
        label: 'page 42',
        createdAt: addedAt,
      ),
    );
    await HighlightStore.add(
      Highlight(
        id: 'hl-1',
        bookId: 'book-1',
        chunkIndex: 1,
        start: 0,
        end: 5,
        text: 'hello',
        color: Highlight.defaultColor,
        createdAt: addedAt,
      ),
    );

    final zipBytes = BackupExporter.build();

    // Wipe everything the export just read, to prove restore rebuilds it
    // from the backup alone rather than coincidentally reading it back from
    // stores that were never actually cleared.
    for (final b in LibraryStore.loadAll()) {
      await LibraryStore.delete(b.id);
    }
    await FolderStore.delete('folder-1');
    expect(LibraryStore.loadAll(), isEmpty);

    final summary = await BackupImporter.restore(zipBytes);
    expect(summary.books, 1);
    expect(summary.folders, 1);
    expect(summary.bookmarks, 1);
    expect(summary.highlights, 1);

    final restored = LibraryStore.loadAll().single;
    expect(restored.id, 'book-1');
    expect(restored.name, 'My Note');
    expect(restored.addedAt, addedAt);
    expect(restored.lastOpenedAt, lastOpenedAt);
    expect(restored.modifiedAt, modifiedAt);
    expect(restored.position, 42);
    expect(restored.progress, 0.5);
    expect(restored.folderId, 'folder-1');
    expect(String.fromCharCodes(restored.bytes), 'hello world');

    final restoredFolder = FolderStore.loadAll().single;
    expect(restoredFolder.name, 'My Folder');

    final restoredBookmark = BookmarkStore.loadAll().single;
    expect(restoredBookmark.label, 'page 42');

    final restoredHighlight = HighlightStore.loadAll().single;
    expect(restoredHighlight.text, 'hello');
  });

  test('a book with no modifiedAt round-trips as null', () async {
    final addedAt = DateTime.utc(2026, 1, 1);
    await LibraryStore.save(
      Book(
        id: 'book-2',
        name: 'Untouched',
        format: BookFormat.note,
        bytes: Uint8List.fromList('x'.codeUnits),
        addedAt: addedAt,
      ),
    );

    final zipBytes = BackupExporter.build();
    await LibraryStore.delete('book-2');

    await BackupImporter.restore(zipBytes);
    expect(LibraryStore.loadAll().single.modifiedAt, isNull);
  });
}
