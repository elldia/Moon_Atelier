import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ebk/data/bookmark_store.dart';
import 'package:ebk/data/comic_settings_controller.dart';
import 'package:ebk/data/comic_settings_store.dart';
import 'package:ebk/data/folder_store.dart';
import 'package:ebk/data/highlight_store.dart';
import 'package:ebk/data/library_store.dart';
import 'package:ebk/data/markdown_help_store.dart';
import 'package:ebk/data/onboarding_store.dart';
import 'package:ebk/data/reading_settings_controller.dart';
import 'package:ebk/data/reading_settings_store.dart';
import 'package:ebk/main.dart';

void main() {
  late Directory tempDir;

  // Mirrors main()'s init sequence (minus Hive.initFlutter, which needs the
  // path_provider plugin main() gets from the real platform) — LibraryScreen
  // and its onboarding overlay reach into every one of these stores.
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ebk_hive_test_');
    Hive.init(tempDir.path);
    await LibraryStore.init();
    await ReadingSettingsStore.init();
    await ReadingSettingsController.init();
    await ComicSettingsStore.init();
    await ComicSettingsController.init();
    await BookmarkStore.init();
    await HighlightStore.init();
    await FolderStore.init();
    await OnboardingStore.init();
    await MarkdownHelpStore.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('Library screen shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // MyApp opens on a ~800ms SplashScreen before handing off to Home (which
    // itself forks between the e-book reader and the comic viewer); wait it
    // out, then drill into the e-book library to reach the empty-state UI
    // this test actually cares about.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이북 리더'));
    await tester.pumpAndSettle();

    expect(find.text('아직 추가된 파일이 없습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
