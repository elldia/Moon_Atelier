import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/bookmark_store.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/bookmark.dart';
import '../utils/comic_archive.dart';
import '../widgets/glass.dart';
import '../widgets/page_jump_row.dart';
import 'saved_items_screen.dart';

const _uuid = Uuid();

/// A page-by-page viewer for a comic archive (.cbz / image-only .zip),
/// mirroring [PdfViewerScreen]'s page-based navigation (bookmarks, page
/// jump, progress) but rendering plain page images instead of PDF pages.
class ComicViewerScreen extends StatefulWidget {
  final String bookId;
  final String title;
  final Uint8List bytes;
  final int? initialPage;
  final ValueChanged<int>? onPositionChanged;
  final ValueChanged<double>? onProgressChanged;

  const ComicViewerScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.bytes,
    this.initialPage,
    this.onPositionChanged,
    this.onProgressChanged,
  });

  @override
  State<ComicViewerScreen> createState() => _ComicViewerScreenState();
}

class _ComicViewerScreenState extends State<ComicViewerScreen> {
  ComicArchive? _archive;
  Object? _loadError;
  late final PageController _pageController;
  late int _page; // 1-based
  Timer? _saveDebounce;
  bool _uiVisible = true;

  @override
  void initState() {
    super.initState();
    _page = (widget.initialPage ?? 1).clamp(1, 1 << 30);
    try {
      final archive = ComicArchive.fromBytes(widget.bytes);
      if (archive.pageCount == 0) {
        throw StateError('no pages found');
      }
      _page = _page.clamp(1, archive.pageCount);
      _archive = archive;
    } catch (e) {
      _loadError = e;
    }
    _pageController = PageController(initialPage: _page - 1);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _page = index + 1);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      widget.onPositionChanged?.call(_page);
      final count = _archive?.pageCount ?? 0;
      if (count > 0) {
        widget.onProgressChanged?.call((_page / count).clamp(0.0, 1.0));
      }
    });
  }

  void _jumpToPage(int target) {
    final count = _archive?.pageCount ?? 0;
    if (count == 0) return;
    final clamped = target.clamp(1, count);
    _pageController.animateToPage(
      clamped - 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
  }

  Future<void> _addBookmark() async {
    final bookmark = Bookmark(
      id: _uuid.v4(),
      bookId: widget.bookId,
      position: _page,
      label: tr('page_n', {'n': '$_page'}),
      createdAt: DateTime.now(),
    );
    await BookmarkStore.add(bookmark);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('bookmark_added'))));
  }

  Future<void> _openSavedItems() async {
    final result = await Navigator.of(context).push<SavedItemJump>(
      MaterialPageRoute(
        builder: (_) => SavedItemsScreen(
          bookId: widget.bookId,
          bookTitle: widget.title,
          showHighlights: false,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final page = result.position;
    if (page is int) _jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final error = _loadError;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: tr('back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr('comic_open_error', {'error': '$error'}),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final archive = _archive!;
    final count = archive.pageCount;

    return AnimatedBuilder(
      animation: ReadingSettingsController.instance,
      builder: (context, _) {
        final settings = ReadingSettingsController.instance.value;
        final narrow = MediaQuery.of(context).size.width < 420;
        final showBar = settings.showProgress && count > 1;

        final progressChip = settings.showProgress
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text('$_page / $count · ${((_page / count) * 100).round()}%'),
                ),
              )
            : const SizedBox.shrink();

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: !_uiVisible
              ? null
              : glassAppBar(
                  context,
                  title: Text(widget.title, overflow: TextOverflow.ellipsis),
                  leading: IconButton(
                    tooltip: tr('back'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  actions: narrow
                      ? [
                          progressChip,
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'bookmark') _addBookmark();
                              if (v == 'saved') _openSavedItems();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'bookmark',
                                child: Text(tr('bookmark_add')),
                              ),
                              PopupMenuItem(
                                value: 'saved',
                                child: Text(tr('bookmark_list')),
                              ),
                            ],
                          ),
                        ]
                      : [
                          progressChip,
                          IconButton(
                            tooltip: tr('bookmark_add'),
                            icon: const Icon(Icons.bookmark_add_outlined),
                            onPressed: _addBookmark,
                          ),
                          IconButton(
                            tooltip: tr('bookmark_list'),
                            icon: const Icon(Icons.bookmarks_outlined),
                            onPressed: _openSavedItems,
                          ),
                        ],
                ),
          body: GestureDetector(
            onTap: () => setState(() => _uiVisible = !_uiVisible),
            child: PageView.builder(
              controller: _pageController,
              itemCount: count,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.memory(
                    archive.pageBytes(index),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton: !_uiVisible
              ? null
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'prev',
                      onPressed: () => _jumpToPage(_page - 1),
                      child: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.small(
                      heroTag: 'next',
                      onPressed: () => _jumpToPage(_page + 1),
                      child: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
          bottomNavigationBar: showBar && _uiVisible
              ? SafeArea(
                  child: SizedBox(
                    height: 36,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
                              ),
                              child: Slider(
                                value: (_page / count).clamp(0.0, 1.0),
                                onChanged: (ratio) =>
                                    _jumpToPage((ratio * count).round()),
                              ),
                            ),
                          ),
                          if (count >= 100)
                            Expanded(
                              flex: 3,
                              child: PageJumpRow(
                                onFirst: () => _jumpToPage(1),
                                onBack10: () => _jumpToPage(_page - 10),
                                onForward10: () => _jumpToPage(_page + 10),
                                onLast: () => _jumpToPage(count),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
