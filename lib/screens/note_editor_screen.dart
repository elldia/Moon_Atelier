import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../l10n/strings.dart';
import '../widgets/glass.dart';

/// What [NoteEditorScreen] hands back on save -- null means the user backed
/// out without keeping anything (only possible in create mode; editing an
/// existing note always saves, even if unchanged, since there's nothing to
/// discard back to).
class NoteResult {
  final String title;
  final String content;
  const NoteResult({required this.title, required this.content});
}

/// Create-or-edit screen for a user-authored note (BookFormat.note): a
/// plain-text title plus a raw Markdown body, with Edit/Preview tabs the
/// same way GitHub edits a README. Nothing about `#`/`##`/`*`/`` ` `` is
/// special-cased here -- the Preview tab just runs the body through a
/// standard CommonMark renderer, so ordinary Markdown syntax already works.
class NoteEditorScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;

  const NoteEditorScreen({super.key, this.initialTitle, this.initialContent})
    : assert(
        (initialTitle == null) == (initialContent == null),
        'initialTitle/initialContent must both be null (create) or both set (edit)',
      );

  bool get isEditing => initialContent != null;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with SingleTickerProviderStateMixin {
  late final _titleController = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late final _bodyController = TextEditingController(
    text: widget.initialContent ?? '',
  );
  late final _tabController = TabController(
    // A brand new note opens straight into editing; an existing one opens
    // on Preview first, matching how you'd open a book to read it.
    initialIndex: widget.isEditing ? 1 : 0,
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _save() {
    final content = _bodyController.text;
    if (!widget.isEditing && content.trim().isEmpty) {
      // Nothing worth keeping from a fresh, still-empty note.
      Navigator.of(context).pop();
      return;
    }
    final title = _titleController.text.trim();
    Navigator.of(
      context,
    ).pop(NoteResult(title: title.isEmpty ? tr('note_untitled') : title, content: content));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _save();
      },
      child: Scaffold(
        appBar: glassAppBar(
          context,
          leading: IconButton(
            tooltip: tr('back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: _save,
          ),
          title: TextField(
            controller: _titleController,
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: tr('note_title_hint'),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          actions: [
            IconButton(
              tooltip: tr('save'),
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: tr('note_edit_tab')),
              Tab(text: tr('note_preview_tab')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _bodyController,
                autofocus: !widget.isEditing,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: tr('note_body_hint'),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _bodyController,
              builder: (context, _) => Markdown(
                data: _bodyController.text.trim().isEmpty
                    ? tr('note_preview_empty')
                    : _bodyController.text,
                selectable: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
