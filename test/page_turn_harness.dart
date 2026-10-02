/// Shared page-mode test helpers (see page_turn_test.dart and
/// page_turn_settings_matrix_test.dart).
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:ebk/data/bookmark_store.dart';
import 'package:ebk/data/highlight_store.dart';
import 'package:ebk/screens/epub_viewer_screen.dart';
import 'package:ebk/screens/text_viewer_screen.dart';
import 'package:ebk/utils/text_line_geometry.dart';
import 'package:ebk/widgets/page_turn_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Paragraphs of uneven length with blank lines between some of them, so
/// line boundaries never fall at a fixed interval — the layout that made a
/// fixed "one screen minus one line" step drift.
List<String> samplePagedParagraphs([int count = 120]) => [
  for (var i = 0; i < count; i++)
    '문단 $i ${'가나다라 마바사 ' * (1 + (i * 7) % 9)}'.trim(),
];

String sampleTextContent() {
  final out = StringBuffer();
  // Long enough that even the smallest text on the widest test screen
  // doesn't reach the end of the book within a test's page turns.
  final paragraphs = samplePagedParagraphs(400);
  for (var i = 0; i < paragraphs.length; i++) {
    out.writeln(paragraphs[i]);
    if (i % 4 == 0) out.writeln();
  }
  return out.toString();
}

Uint8List sampleEpub() {
  final a = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  add(
    'OEBPS/content.opf',
    '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>T</dc:title><dc:identifier id="id">x</dc:identifier></metadata><manifest><item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/></manifest><spine toc="ncx"><itemref idref="c1"/></spine></package>',
  );
  add(
    'OEBPS/toc.ncx',
    '<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head></head><docTitle><text>T</text></docTitle><navMap><navPoint id="n1" playOrder="1"><navLabel><text>One</text></navLabel><content src="c1.xhtml"/></navPoint></navMap></ncx>',
  );
  final body = StringBuffer();
  final paragraphs = samplePagedParagraphs();
  for (var i = 0; i < paragraphs.length; i++) {
    if (i % 10 == 0) body.write('<h2>Heading $i</h2>');
    body.write('<p>${paragraphs[i]}</p>');
  }
  add(
    'OEBPS/c1.xhtml',
    '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>One</title></head><body>$body</body></html>',
  );
  return Uint8List.fromList(ZipEncoder().encode(a));
}

/// What one page looks like on screen right now.
class VisiblePage {
  final double pixels;
  final Rect viewport;

  /// Layer-local y where the visible text ends (the mask's top, or the
  /// viewport's full height when nothing is masked).
  final double end;
  const VisiblePage(this.pixels, this.viewport, this.end);
}

double readingPixels(WidgetTester tester) {
  // The reading list's own Scrollable (the outermost one under the layer).
  final state = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(PageTurnLayer),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  return state.position.pixels;
}

VisiblePage visiblePage(WidgetTester tester) {
  final layer = find.byType(PageTurnLayer);
  final viewport = tester.getRect(layer);
  final mask = find.descendant(of: layer, matching: find.byType(ColoredBox));
  final end = mask.evaluate().isEmpty
      ? viewport.height
      : tester.getRect(mask.last).top - viewport.top;
  return VisiblePage(readingPixels(tester), viewport, end);
}

RenderObject readingContent(WidgetTester tester) => tester.renderObject(
  find
      .descendant(
        of: find.byType(PageTurnLayer),
        matching: find.byType(KeyedSubtree),
      )
      .first,
);

/// The page's own invariants: no line is cut by the top edge, and a line
/// cut by the bottom edge sits entirely under the mask.
void expectCleanEdges(WidgetTester tester, VisiblePage page) {
  final root = readingContent(tester);
  final top = textLineAt(root, page.viewport.top + 0.5);
  if (top != null) {
    expect(
      top.top,
      greaterThanOrEqualTo(page.viewport.top - 0.5),
      reason: 'a line is cut by the top edge at pixels ${page.pixels}',
    );
  }
  final bottom = textLineAt(root, page.viewport.top + page.end - 0.5);
  if (bottom != null) {
    expect(
      bottom.bottom,
      lessThanOrEqualTo(page.viewport.top + page.end + 0.5),
      reason: 'a visible line is cut at the bottom at ${page.pixels}',
    );
  }
}

Future<void> settleTurn(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

/// Test-only: opens the text reader on [content] with the current reading
/// settings at [size].
Future<void> pumpTextReader(
  WidgetTester tester, {
  String? content,
  Size size = const Size(400, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: TextViewerScreen(
        bookId: 'b',
        title: 't',
        content: content ?? sampleTextContent(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Test-only: opens the EPUB reader on [sampleEpub] and waits for it to load.
Future<void> pumpEpubReader(
  WidgetTester tester, {
  Size size = const Size(400, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: EpubViewerScreen(bookId: 'e', title: 't', bytes: sampleEpub()),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.byType(PageTurnLayer), findsOneWidget);
}

/// Test-only: opens Hive in a temp dir for the stores the readers touch.
Future<void> initReaderStores() async {
  Hive.init((await Directory.systemTemp.createTemp('ebk_page_turn_')).path);
  await HighlightStore.init();
  await BookmarkStore.init();
}

/// Turns forward [turns] times then back again, checking every page: each
/// forward page starts exactly where the previous one ended, each backward
/// page ends exactly where the one after it started.
Future<void> walkPagesBothWays(WidgetTester tester, {int turns = 12}) async {
  final starts = <double>[];
  var page = visiblePage(tester);
  expectCleanEdges(tester, page);
  final firstEnd = page.end;
  for (var i = 0; i < turns; i++) {
    starts.add(page.pixels);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await settleTurn(tester);
    final next = visiblePage(tester);
    expect(
      next.pixels,
      closeTo(page.pixels + page.end, 0.5),
      reason: 'turn $i: next page must start where this one ended',
    );
    expectCleanEdges(tester, next);
    page = next;
  }
  for (var i = 0; i < turns; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await settleTurn(tester);
    final prev = visiblePage(tester);
    if (prev.pixels <= 0.5) {
      // Back at the start of the book: the same full first page as when
      // it was opened, reaching at least as far as the later page began.
      expect(prev.end, closeTo(firstEnd, 0.5), reason: 'back $i: first page');
      expect(prev.end, greaterThanOrEqualTo(page.pixels - 0.5));
    } else {
      expect(
        prev.pixels + prev.end,
        closeTo(page.pixels, 0.5),
        reason: 'back $i: page must end where the later one started',
      );
      expect(prev.end, greaterThan(page.viewport.height * 0.5));
    }
    expectCleanEdges(tester, prev);
    page = prev;
  }
  expect(starts.first, 0);
}
