import 'package:flutter/material.dart';

import '../data/onboarding_store.dart';
import '../l10n/strings.dart';
import 'glass.dart';

/// Shows the first-run "where everything is" help dialog once, then
/// remembers not to show it again. Safe to call on every library-screen
/// load — it no-ops after the first time.
Future<void> maybeShowOnboarding(BuildContext context) async {
  if (OnboardingStore.hasSeen) return;
  await OnboardingStore.markSeen();
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (context) => const _OnboardingDialog(),
  );
}

class _OnboardingDialog extends StatelessWidget {
  const _OnboardingDialog();

  static const _items = [
    (Icons.add_circle_outline, 'onb_add_title', 'onb_add_desc'),
    (Icons.folder_outlined, 'onb_folder_title', 'onb_folder_desc'),
    (Icons.search, 'onb_search_title', 'onb_search_desc'),
    (Icons.sort, 'onb_sort_title', 'onb_sort_desc'),
    (Icons.delete_outline, 'onb_trash_title', 'onb_trash_desc'),
    (Icons.tune, 'onb_settings_title', 'onb_settings_desc'),
    (Icons.border_color_outlined, 'onb_highlight_title', 'onb_highlight_desc'),
    (Icons.bookmark_add_outlined, 'onb_bookmark_title', 'onb_bookmark_desc'),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        opacity: 0.75,
        child: SizedBox(
          width: size.width < 560 ? size.width - 32 : 480,
          height: (size.height * 0.8).clamp(360, 620),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories),
                    const SizedBox(width: 10),
                    Text(
                      tr('onboarding_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final (icon, titleKey, descKey) = _items[index];
                    return ListTile(
                      leading: Icon(icon),
                      title: Text(tr(titleKey)),
                      subtitle: Text(tr(descKey)),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('close')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
