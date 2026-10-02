import 'package:ebk/data/reading_settings_controller.dart';
import 'package:ebk/models/reading_settings.dart';
import 'package:ebk/screens/text_viewer_screen.dart';
import 'package:ebk/widgets/page_turn_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_turn_harness.dart';

void main() {
  setUpAll(initReaderStores);

  setUp(() {
    ReadingSettingsController.instance.value = ReadingSettings.defaults
        .copyWith(readingMode: ReadingMode.page);
  });
  tearDown(() {
    ReadingSettingsController.instance.value = ReadingSettings.defaults;
  });

  testWidgets('text reader pages break on whole lines, both ways', (
    tester,
  ) async {
    await pumpTextReader(tester);
    await walkPagesBothWays(tester);
  });

  testWidgets('larger text and line spacing still break on whole lines', (
    tester,
  ) async {
    ReadingSettingsController.instance.value = ReadingSettings.defaults
        .copyWith(readingMode: ReadingMode.page, fontSize: 24, lineHeight: 2.1);
    await pumpTextReader(tester);
    await walkPagesBothWays(tester);
  });

  testWidgets('animated page turns end on whole lines too', (tester) async {
    ReadingSettingsController.instance.value = ReadingSettings.defaults
        .copyWith(readingMode: ReadingMode.page, animatePageTurns: true);
    await pumpTextReader(tester);
    final start = visiblePage(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    final next = visiblePage(tester);
    expect(next.pixels, closeTo(start.pixels + start.end, 0.5));
    expectCleanEdges(tester, next);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    final back = visiblePage(tester);
    expect(back.pixels + back.end, closeTo(next.pixels, 0.5));
    expectCleanEdges(tester, back);
  });

  testWidgets('the end of the book stops cleanly on whole lines', (
    tester,
  ) async {
    await pumpTextReader(
      tester,
      content: samplePagedParagraphs(30).join('\n\n'),
    );
    for (var i = 0; i < 40; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settleTurn(tester);
    }
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(PageTurnLayer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.maxScrollExtent, 0.5),
    );
    expectCleanEdges(tester, visiblePage(tester));
  });

  testWidgets('edge taps, swipes and the middle tap', (tester) async {
    await pumpTextReader(tester);
    final start = visiblePage(tester);

    await tester.tapAt(const Offset(380, 400)); // right edge: forward
    await settleTurn(tester);
    expect(readingPixels(tester), closeTo(start.end, 0.5));

    await tester.tapAt(const Offset(20, 400)); // left edge: back
    await settleTurn(tester);
    expect(readingPixels(tester), 0);

    // A touch swipe turns forward; it doesn't scroll freely.
    await tester.flingFrom(const Offset(300, 400), const Offset(-200, 0), 800);
    await settleTurn(tester);
    expect(readingPixels(tester), closeTo(start.end, 0.5));

    expect(find.byType(AppBar), findsOneWidget);
    await tester.tapAt(const Offset(200, 400)); // middle: toggles the UI
    await settleTurn(tester);
    expect(find.byType(AppBar), findsNothing);
    await tester.tapAt(const Offset(200, 400));
    await settleTurn(tester);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('scroll mode keeps free scrolling and ignores edge taps', (
    tester,
  ) async {
    ReadingSettingsController.instance.value = ReadingSettings.defaults;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TextViewerScreen(
          bookId: 'b',
          title: 't',
          content: sampleTextContent(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PageTurnLayer), findsNothing);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.tapAt(const Offset(380, 400));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('EPUB pages break on whole lines, both ways', (tester) async {
    await pumpEpubReader(tester);
    await walkPagesBothWays(tester);
  });
}
