import 'dart:io';
import 'dart:typed_data';

import 'package:ebk/data/folder_store.dart';
import 'package:ebk/data/library_store.dart';
import 'package:ebk/models/book.dart';
import 'package:ebk/models/folder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ebk_folder_kind_');
    Hive.init(tempDir.path);
    await LibraryStore.init();
    await FolderStore.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  Future<void> addLegacyFolder(String id, String name) async {
    final box = await Hive.openBox('folders');
    await box.put(id, {
      'name': name,
      'createdAt': DateTime.utc(2026).toIso8601String(),
    });
  }

  Future<void> addBook(String id, BookFormat format, String? folderId) =>
      LibraryStore.save(
        Book(
          id: id,
          name: id,
          format: format,
          bytes: Uint8List(1),
          addedAt: DateTime.utc(2026),
          folderId: folderId,
        ),
      );

  test('legacy folders are split into e-book and comic folders', () async {
    await addLegacyFolder('empty', 'Empty');
    await addLegacyFolder('ebooks', 'Novels');
    await addLegacyFolder('comics', 'Manga');
    await addLegacyFolder('mixed', 'Mixed');
    await addBook('n1', BookFormat.epub, 'ebooks');
    await addBook('c1', BookFormat.comic, 'comics');
    await addBook('n2', BookFormat.txt, 'mixed');
    await addBook('c2', BookFormat.comic, 'mixed');

    await FolderStore.assignLegacyKinds();

    final folders = FolderStore.loadAll();
    String kindOf(String id) =>
        folders.singleWhere((f) => f.id == id).kind.name;
    expect(kindOf('empty'), 'ebook');
    expect(kindOf('ebooks'), 'ebook');
    expect(kindOf('comics'), 'comic');
    expect(kindOf('mixed'), 'ebook');

    // The mixed folder's comic moved to a new comic folder of the same name.
    final mixedComic = folders.singleWhere(
      (f) => f.name == 'Mixed' && f.kind == BookKind.comic,
    );
    final books = {for (final b in LibraryStore.loadAll()) b.id: b};
    expect(books['c2']!.folderId, mixedComic.id);
    expect(books['n2']!.folderId, 'mixed');

    // Running again changes nothing.
    await FolderStore.assignLegacyKinds();
    expect(FolderStore.loadAll().length, folders.length);
  });

  test(
    'explicit ids are re-sorted even after being saved with a kind',
    () async {
      // What a restore of an old backup does: each folder is written back as
      // an e-book folder first, then its id is passed in explicitly.
      await FolderStore.add(
        Folder(
          id: 'restored',
          name: 'Manga',
          createdAt: DateTime.utc(2026),
          kind: BookKind.ebook,
        ),
      );
      await addBook('c1', BookFormat.comic, 'restored');

      await FolderStore.assignLegacyKinds();
      expect(FolderStore.loadAll().single.kind, BookKind.ebook);

      await FolderStore.assignLegacyKinds(['restored']);
      expect(FolderStore.loadAll().single.kind, BookKind.comic);
    },
  );
}
