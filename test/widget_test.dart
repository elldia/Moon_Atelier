import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ebk/data/library_store.dart';
import 'package:ebk/main.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ebk_hive_test_');
    Hive.init(tempDir.path);
    await LibraryStore.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('Library screen shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('내 서재'), findsOneWidget);
    expect(find.text('아직 추가된 파일이 없습니다.'), findsOneWidget);
    expect(find.text('파일 열기'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
