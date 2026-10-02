import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ebk/screens/comic_viewer_screen.dart';
import 'package:ebk/utils/comic_archive.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zipOf(int pages) {
  final archive = Archive();
  for (var i = 1; i <= pages; i++) {
    final data = Uint8List.fromList(List.filled(256, i));
    archive.addFile(ArchiveFile('p$i.jpg', data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('ComicArchive.pageBytes', () {
    test('the archive itself hands out a new bytes object on every read', () {
      // Why pageBytes needs its own cache: this is what it used to return.
      final file = ZipDecoder().decodeBytes(_zipOf(1)).files.single;
      expect(identical(file.content, file.content), isFalse);
    });

    test('returns the same bytes object for a page every time', () {
      final archive = ComicArchive.fromBytes(_zipOf(3));
      expect(identical(archive.pageBytes(1), archive.pageBytes(1)), isTrue);
      expect(archive.pageBytes(1), everyElement(2));
    });

    test('so a precached page and the shown page share one cache key', () {
      final archive = ComicArchive.fromBytes(_zipOf(3));
      final precached = ResizeImage(
        MemoryImage(archive.pageBytes(0)),
        width: 1080,
      );
      final shown = ResizeImage(
        MemoryImage(archive.pageBytes(0)),
        width: 1080,
      );
      expect(precached, shown);
    });
  });

  group('comicPrecacheIndices', () {
    test('single page: four ahead, one behind', () {
      expect(comicPrecacheIndices(10, 100, twoPage: false), [
        11,
        12,
        13,
        14,
        9,
      ]);
    });

    test('two-page spread: the next two spreads and the previous one', () {
      expect(comicPrecacheIndices(10, 100, twoPage: true), [
        12,
        13,
        14,
        15,
        8,
        9,
      ]);
    });

    test('stays inside the book at both ends', () {
      expect(comicPrecacheIndices(0, 100, twoPage: false), [1, 2, 3, 4]);
      expect(comicPrecacheIndices(98, 100, twoPage: false), [99, 97]);
      expect(comicPrecacheIndices(0, 1, twoPage: false), isEmpty);
    });
  });
}
