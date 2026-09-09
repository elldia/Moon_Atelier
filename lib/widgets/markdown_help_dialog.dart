import 'package:flutter/material.dart';

import '../data/markdown_help_store.dart';
import '../l10n/strings.dart';
import 'glass.dart';

class _Shortcut {
  final String syntax;
  final String labelKey;
  const _Shortcut(this.syntax, this.labelKey);
}

const _shortcuts = [
  _Shortcut('# 제목', 'md_help_h1'),
  _Shortcut('## 부제목', 'md_help_h2'),
  _Shortcut('**굵게**', 'md_help_bold'),
  _Shortcut('*기울임*', 'md_help_italic'),
  _Shortcut('- 항목', 'md_help_list'),
  _Shortcut('> 인용', 'md_help_quote'),
  _Shortcut('`코드`', 'md_help_code'),
  _Shortcut('[링크](주소)', 'md_help_link'),
];

/// Shows the note editor's Markdown-shortcuts cheatsheet, unless the user
/// has already dismissed it for good. Safe to call every time the editor
/// opens -- no-ops after "다신 안 보기".
Future<void> maybeShowMarkdownHelp(BuildContext context) async {
  if (MarkdownHelpStore.hasSeen) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _MarkdownHelpDialog(),
  );
}

class _MarkdownHelpDialog extends StatelessWidget {
  const _MarkdownHelpDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassCard(
        opacity: 0.92,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('md_help_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                tr('md_help_intro'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              for (final s in _shortcuts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          s.syntax,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward, size: 14),
                      const SizedBox(width: 8),
                      Text(tr(s.labelKey)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('onb_show_again')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await MarkdownHelpStore.markSeen();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(tr('onb_never_show')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
