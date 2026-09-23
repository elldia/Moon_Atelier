import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/library_store.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/book.dart';
import '../utils/browser_title.dart';
import '../widgets/glass.dart';
import 'library_screen.dart';

/// Where the web build points users who want an offline fallback — the
/// repo's GitHub Releases page, so the link keeps working as new Windows
/// builds get published there without this app needing an update.
final _windowsDownloadUrl = Uri.parse(
  'https://github.com/elldia/Moon_Atelier/releases',
);

/// Google Play requires the privacy policy to be reachable both from the
/// Play Console store listing *and* from inside the app itself — this link
/// is that second copy, shown on every platform (not just web) so it's
/// there for an Android review too. Hosted as a static page alongside the
/// web build (see web/privacy.html) rather than as an in-app screen, so
/// there's exactly one copy to keep accurate.
final _privacyPolicyUrl = Uri.parse(
  'https://elldia.github.io/Moon_Atelier/privacy.html',
);

/// The app's start screen: a fork between the two independent tools it
/// bundles — the e-book reader and the comic viewer — so each gets its own
/// uncluttered library/menu instead of mixing both kinds of files (and
/// their format-specific actions) into one screen. Also surfaces a
/// "이어보기" (continue reading) shortcut to the single most recently
/// opened book/comic, if there is one, so a returning user doesn't have to
/// go through the library list just to pick up where they left off.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// True for a web build running inside a mobile/tablet browser -- Flutter
  /// web infers this from the user agent via [defaultTargetPlatform]. The
  /// Windows download link is desktop-only, so tapping it here should
  /// explain that instead of sending a phone/tablet browser to a page it
  /// can't do anything useful with.
  bool get _isMobileOrTabletWeb =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _openWindowsDownload() {
    if (_isMobileOrTabletWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('windows_download_desktop_only'))),
      );
      return;
    }
    launchUrl(_windowsDownloadUrl, webOnlyWindowName: '_blank');
  }

  /// Pushes the given library, optionally auto-opening one book in it, then
  /// refreshes on return — opening a book (from here or from within the
  /// library screen itself) can change its lastOpenedAt/progress, which the
  /// continue-reading card needs to reflect without waiting on some
  /// unrelated rebuild.
  Future<void> _openLibrary(BookKind kind, {String? initialOpenBookId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LibraryScreen(kind: kind, initialOpenBookId: initialOpenBookId),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ReadingSettingsController.instance,
      builder: (context, _) {
        final appName = ReadingSettingsController.instance.value.appName;
        setBrowserTitle(appName.label);
        final recentlyOpened = LibraryStore.loadAll()
            .where((b) => b.lastOpenedAt != null)
            .toList();
        final continueBook = recentlyOpened.isEmpty
            ? null
            : recentlyOpened.first;
        return Scaffold(
          appBar: glassAppBar(context, title: Text(appName.label)),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (continueBook != null) ...[
                        _ContinueReadingCard(
                          book: continueBook,
                          onTap: () => _openLibrary(
                            continueBook.format.kind,
                            initialOpenBookId: continueBook.id,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      _HomeEntryCard(
                        icon: Icons.menu_book,
                        title: tr('home_ebook_title'),
                        description: tr('home_ebook_desc'),
                        onTap: () => _openLibrary(BookKind.ebook),
                      ),
                      const SizedBox(height: 20),
                      _HomeEntryCard(
                        icon: Icons.auto_stories,
                        title: tr('home_comic_title'),
                        description: tr('home_comic_desc'),
                        onTap: () => _openLibrary(BookKind.comic),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _openWindowsDownload,
                          child: Text(
                            tr('home_windows_download'),
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => launchUrl(
                          _privacyPolicyUrl,
                          webOnlyWindowName: '_blank',
                        ),
                        child: Text(
                          tr('privacy_policy'),
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
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
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// The "이어보기" shortcut card — same shape as [_HomeEntryCard] but shows
/// the specific book's title/progress instead of a static description.
class _ContinueReadingCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _ContinueReadingCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = book.progress;
    return GlassCard(
      opacity: 0.55,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(
            book.format.kind == BookKind.comic
                ? Icons.auto_stories
                : Icons.menu_book,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('continue_reading_section'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  book.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
