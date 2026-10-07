import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:ebk/data/cover_store.dart';
import 'package:ebk/data/library_store.dart';
import 'package:ebk/models/book.dart';
import 'package:ebk/utils/comic_cover.dart';
import 'package:ebk/utils/comic_cover_cache.dart';
import 'package:ebk/widgets/comic_cover_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// A solid-color PNG page of [width]x[height].
Future<Uint8List> _png(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// A comic archive whose pages, in reading order, are red then blue —
/// stored out of order to prove the cover is the first *page*, not the
/// first zip entry.
Future<Uint8List> _comic() async {
  final archive = Archive();
  final blue = await _png(1200, 1700, const Color(0xFF0000FF));
  final red = await _png(1200, 1700, const Color(0xFFFF0000));
  archive.addFile(ArchiveFile('page10.png', blue.length, blue));
  archive.addFile(ArchiveFile('page2.png', red.length, red));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Future<(int, int, Color)> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final pixel = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final color = Color.fromARGB(
    pixel!.getUint8(3),
    pixel.getUint8(0),
    pixel.getUint8(1),
    pixel.getUint8(2),
  );
  return (image.width, image.height, color);
}

void main() {
  test('grid columns: phones 3, tablets 4, desktops 6', () {
    expect(coverGridColumns(360), 3);
    expect(coverGridColumns(599), 3);
    expect(coverGridColumns(600), 4);
    expect(coverGridColumns(632), 4); // a 7" e-reader
    expect(coverGridColumns(1023), 4);
    expect(coverGridColumns(1024), 6);
    expect(coverGridColumns(1920), 6);
  });

  testWidgets('the cover is a small copy of the first page', (tester) async {
    await tester.runAsync(() async {
      final cover = await buildComicCover(await _comic());
      expect(cover, isNotNull);
      final (width, height, color) = await _decode(cover!);
      expect(width, comicCoverWidth);
      expect(height, closeTo(1700 * comicCoverWidth / 1200, 1));
      expect(color, const Color(0xFFFF0000)); // page2 comes before page10
      expect(cover.length, lessThan(100 * 1024));
    });
  });

  testWidgets('an archive without images has no cover', (tester) async {
    await tester.runAsync(() async {
      final archive = Archive()..addFile(ArchiveFile('a.txt', 1, [65]));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(await buildComicCover(zip), isNull);
      expect(await buildComicCover(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  testWidgets('the cache makes a missing cover once, then reuses it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('ebk_covers_');
      addTearDown(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });
      Hive.init(dir.path);
      await LibraryStore.init();
      await CoverStore.init();
      await LibraryStore.add(
        Book(
          id: 'c',
          name: 'C',
          format: BookFormat.comic,
          addedAt: DateTime.utc(2026),
        ),
        await _comic(),
      );

      final cache = ComicCoverCache();
      var notified = 0;
      cache.addListener(() => notified++);
      expect(cache.coverFor('c'), isNull);
      cache.request('c');
      cache.request('c'); // asking twice queues it once
      while (cache.coverFor('c') == null) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(notified, 1);
      expect(cache.coverFor('c'), isNotEmpty);
      expect(await CoverStore.load('c'), cache.coverFor('c'));

      // A fresh cache (next visit) loads the stored cover instead.
      await LibraryStore.delete('c'); // contents gone: can't be remade
      final next = ComicCoverCache()..request('c');
      while (next.coverFor('c') == null) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(next.coverFor('c'), cache.coverFor('c'));

      await next.forget('c');
      expect(await CoverStore.load('c'), isNull);
      cache.dispose();
      next.dispose();
    });
  });

  group('cover grid', () {
    final books = [
      for (var i = 0; i < 8; i++)
        Book(
          id: 'b$i',
          name: 'Comic $i',
          format: BookFormat.comic,
          addedAt: DateTime.utc(2026),
          progress: i == 0 ? 0.5 : null,
        ),
    ];

    Future<List<String>> pumpGrid(
      WidgetTester tester,
      double width, {
      bool selectionMode = false,
      void Function(Book)? onTap,
      void Function(Book, String)? onAction,
    }) async {
      final requested = <String>[];
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComicCoverGrid(
              folders: const [],
              books: books,
              folderCounts: const {},
              selectionMode: selectionMode,
              selectedFolderIds: const {},
              selectedBookIds: const {'b1'},
              coverFor: (id) => id == 'b2' ? Uint8List(0) : null,
              requestCover: requested.add,
              onFolderTap: (_) {},
              onDeleteFolder: (_) {},
              onBookTap: onTap ?? (_) {},
              bookMenu: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
              ],
              onBookAction: onAction ?? (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();
      return requested;
    }

    int columnsShown(WidgetTester tester) {
      final tops = find
          .text('Comic 0')
          .evaluate()
          .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
          .first;
      return [
        for (var i = 0; i < books.length; i++)
          if (find.text('Comic $i').evaluate().isNotEmpty &&
              tester.getTopLeft(find.text('Comic $i')).dy == tops)
            i,
      ].length;
    }

    for (final (width, columns) in [(400.0, 3), (800.0, 4), (1400.0, 6)]) {
      testWidgets('${width.toInt()}px wide shows $columns per row', (
        tester,
      ) async {
        await pumpGrid(tester, width);
        expect(columnsShown(tester), columns);
      });
    }

    testWidgets('asks for missing covers and marks progress', (tester) async {
      final requested = await pumpGrid(tester, 400);
      expect(requested, contains('b0'));
      expect(requested, isNot(contains('b2'))); // known to have none
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
    });

    testWidgets('tapping opens, the menu acts, selection shows checks', (
      tester,
    ) async {
      Book? opened;
      String? action;
      await pumpGrid(
        tester,
        400,
        onTap: (b) => opened = b,
        onAction: (b, a) => action = '${b.id}:$a',
      );
      await tester.tap(find.text('Comic 0'));
      expect(opened?.id, 'b0');

      // Loading covers spin forever, so step time instead of settling
      // (a frame to start each route transition, then past its end).
      Future<void> step() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await step();
      await tester.tap(find.text('Rename'));
      await step();
      expect(action, 'b0:rename');

      await pumpGrid(tester, 400, selectionMode: true);
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // b1
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
