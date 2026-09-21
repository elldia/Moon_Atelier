import 'package:flutter/material.dart';

import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/book.dart';
import '../widgets/glass.dart';
import 'library_screen.dart';

/// The app's start screen: a fork between the two independent tools it
/// bundles — the e-book reader and the comic viewer — so each gets its own
/// uncluttered library/menu instead of mixing both kinds of files (and
/// their format-specific actions) into one screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ReadingSettingsController.instance,
      builder: (context, _) {
        final appName = ReadingSettingsController.instance.value.appName;
        return Scaffold(
          appBar: glassAppBar(context, title: Text(appName.label)),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HomeEntryCard(
                        icon: Icons.menu_book,
                        title: tr('home_ebook_title'),
                        description: tr('home_ebook_desc'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const LibraryScreen(kind: BookKind.ebook),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _HomeEntryCard(
                        icon: Icons.auto_stories,
                        title: tr('home_comic_title'),
                        description: tr('home_comic_desc'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const LibraryScreen(kind: BookKind.comic),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _HomeEntryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      opacity: 0.55,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Icon(icon, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
