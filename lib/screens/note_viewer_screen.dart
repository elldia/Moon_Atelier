import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../l10n/strings.dart';
import '../widgets/glass.dart';

/// Read-only rendered view of a user-authored note (BookFormat.note) --
/// opened when tapping the note in the library, same as any other book.
/// Editing only happens through the library item's "..." menu ("수정"),
/// which opens NoteEditorScreen separately; this screen has no edit entry
/// point of its own.
class NoteViewerScreen extends StatelessWidget {
  final String title;
  final String content;

  const NoteViewerScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: glassAppBar(
        context,
        title: Text(title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: tr('back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: tr('home'),
            icon: const Icon(Icons.home_outlined),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Markdown(
        data: content.trim().isEmpty ? tr('note_preview_empty') : content,
        selectable: true,
        // CommonMark normally collapses a single Enter within a paragraph
        // into a space -- most people writing a plain note expect every
        // Enter to show up as a line break, so treat it like one.
        softLineBreak: true,
      ),
    );
  }
}
