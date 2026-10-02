import 'dart:io';
import 'dart:typed_data';

import 'package:ebk/data/library_store.dart';
import 'package:ebk/models/book.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ebk_library_store_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  /// A book saved the old way: metadata and contents in one 'library' entry.
  Future<void> saveLegacy(String id, BookFormat format, Uint8List bytes) async {
    final box = await Hive.openBox('library');
    await box.put(id, {
      'name': id,
      'format': format.name,
      'bytes': bytes,
      'addedAt': DateTime.utc(2026).toIso8601String(),
      'position': 120.0,
      'progress': 0.25,
      'folderId': 'f1',
    });
    await box.close();
  }

  test(
    'moves an old single-box library over without losing anything',
    () async {
      final txt = Uint8List.fromList([0xEA, 0xB0, 0x80, 0x41, 0x42]); // "가AB"
      final comic = Uint8List.fromList(List.filled(4096, 7));
      await saveLegacy('t', BookFormat.txt, txt);
      await saveLegacy('c', BookFormat.comic, comic);

      await LibraryStore.init();

      final books = {for (final b in LibraryStore.loadAll()) b.id: b};
      expect(books.keys, unorderedEquals(['t', 'c']));
      expect(books['t']!.position, 120.0);
      expect(books['t']!.progress, 0.25);
      expect(books['t']!.folderId, 'f1');
      expect(books['t']!.charCount, 3);
      expect(books['c']!.charCount, isNull);
      expect(await LibraryStore.loadBytes('t'), txt);
      expect(await LibraryStore.loadBytes('c'), comic);

      // The metadata box no longer carries any book contents.
      final meta = Hive.box('library');
      for (final key in meta.keys) {
        expect((meta.get(key) as Map).containsKey('bytes'), isFalse);
      }
    },
  );

  test('a moved library opens the same way again', () async {
    await saveLegacy('t', BookFormat.txt, Uint8List.fromList([0x41]));
    await LibraryStore.init();
    await Hive.close();

    await LibraryStore.init();
    expect(LibraryStore.loadAll().single.id, 't');
    expect(await LibraryStore.loadBytes('t'), [0x41]);
  });

  test('saving a reading position leaves the contents alone', () async {
    await LibraryStore.init();
    final book = Book(
      id: 'b',
      name: 'B',
      format: BookFormat.epub,
      addedAt: DateTime.utc(2026),
    );
    final bytes = Uint8List.fromList(List.filled(1 << 16, 3));
    await LibraryStore.add(book, bytes);

    final bytesFile = File('${tempDir.path}/library_bytes.hive');
    final sizeBefore = bytesFile.lengthSync();
    for (var i = 0; i < 20; i++) {
      await LibraryStore.save(book.copyWith(position: 'cfi-$i'));
    }
    expect(bytesFile.lengthSync(), sizeBefore);
    // The metadata file stays far smaller than even one copy of the book.
    expect(
      File('${tempDir.path}/library.hive').lengthSync(),
      lessThan(bytes.length),
    );
    expect(LibraryStore.loadAll().single.position, 'cfi-19');
    expect(await LibraryStore.loadBytes('b'), bytes);
  });

  test('replacing contents and deleting', () async {
    await LibraryStore.init();
    final book = Book(
      id: 'n',
      name: 'N',
      format: BookFormat.note,
      addedAt: DateTime.utc(2026),
    );
    await LibraryStore.add(book, Uint8List.fromList([1]));
    await LibraryStore.saveBytes('n', Uint8List.fromList([2, 2]));
    expect(await LibraryStore.loadBytes('n'), [2, 2]);

    await LibraryStore.delete('n');
    expect(LibraryStore.loadAll(), isEmpty);
    expect(await LibraryStore.loadBytes('n'), isNull);
  });
}
