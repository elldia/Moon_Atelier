import 'package:ebk/widgets/cloud_browser_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDrive implements CloudDriveSource {
  final listed = <String?>[];

  @override
  String get title => 'Fake Drive';

  @override
  Future<List<CloudEntry>> list(String? folderId) async {
    listed.add(folderId);
    if (folderId == null) {
      return const [
        CloudEntry(id: 'books', name: 'Books', isDirectory: true),
        CloudEntry(id: 'n', name: 'notes.txt', isDirectory: false, size: 10),
        CloudEntry(id: 'p', name: 'photo.jpg', isDirectory: false),
      ];
    }
    return const [
      CloudEntry(id: 'e', name: 'novel.epub', isDirectory: false, size: 2048),
    ];
  }

  @override
  Future<String> downloadUrl(CloudEntry file) async =>
      'https://dl.example/${file.id}';
}

void main() {
  testWidgets('browses into a folder, back out, and picks a file', (
    tester,
  ) async {
    final drive = _FakeDrive();
    CloudPick? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showCloudBrowserDialog(
              context,
              source: drive,
              extensions: ['.epub', '.txt'],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Fake Drive'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('photo.jpg'), findsNothing); // filtered out

    await tester.tap(find.text('Books'));
    await tester.pumpAndSettle();
    expect(find.text('/Books'), findsOneWidget);
    expect(find.text('novel.epub'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    expect(find.text('notes.txt'), findsOneWidget);
    expect(drive.listed, [null, 'books', null]);

    await tester.tap(find.text('Books'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('novel.epub'));
    await tester.pumpAndSettle();
    expect(picked, (name: 'novel.epub', url: 'https://dl.example/e'));
  });
}
