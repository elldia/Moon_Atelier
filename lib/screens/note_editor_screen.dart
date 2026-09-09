import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../widgets/glass.dart';
import '../widgets/markdown_help_dialog.dart';

/// What [NoteEditorScreen] hands back when the checkmark is pressed -- the
/// only way out that saves. Backing out (arrow / system back) always
/// discards instead: in create mode after confirming, in edit mode straight
/// away, since the previously-saved version is untouched either way.
class NoteResult {
  final String title;
  final String content;
  const NoteResult({required this.title, required this.content});
}

/// Create-or-edit screen for a user-authored note (BookFormat.note): a
/// plain-text title plus a raw Markdown body. Purely a writing surface --
/// no preview here, since `#`/`##`/`*`/`` ` `` don't need any special
/// handling while typing; rendering only happens when reading the saved
/// note back in NoteViewerScreen.
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

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final _titleController = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late final _bodyController = TextEditingController(
    text: widget.initialContent ?? '',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowMarkdownHelp(context);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    Navigator.of(context).pop(
      NoteResult(
        title: title.isEmpty ? tr('note_untitled') : title,
        content: _bodyController.text,
      ),
    );
  }

  /// The back arrow / system back gesture never saves by itself -- only the
  /// checkmark does. Editing an existing note just leaves (there's nothing
  /// to "discard" back to); creating a fresh one asks first, since backing
  /// out here would otherwise silently drop everything just typed.
  Future<void> _handleBack() async {
    if (widget.isEditing) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('note_discard_title')),
        content: Text(tr('note_discard_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('note_keep_writing')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('note_leave_without_saving')),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: glassAppBar(
          context,
          leading: IconButton(
            tooltip: tr('back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
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
        ),
        body: Padding(
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
      ),
    );
  }
}
