import 'dart:async';
import 'dart:typed_data';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/bookmark_store.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/bookmark.dart';
import '../widgets/glass.dart';
import '../widgets/reading_settings_sheet.dart';
import 'saved_items_screen.dart';

const _uuid = Uuid();

class EpubViewerScreen extends StatefulWidget {
  final String bookId;
  final String title;
  final Uint8List bytes;
  final String? initialCfi;
  final ValueChanged<String>? onPositionChanged;
  final ValueChanged<double>? onProgressChanged;

  const EpubViewerScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.bytes,
    this.initialCfi,
    this.onPositionChanged,
    this.onProgressChanged,
  });

  @override
  State<EpubViewerScreen> createState() => _EpubViewerScreenState();
}

class _EpubViewerScreenState extends State<EpubViewerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final EpubController _epubController;
  final _progressNotifier = ValueNotifier<double>(0);
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _epubController = EpubController(
      document: EpubDocument.openData(widget.bytes),
      epubCfi: widget.initialCfi,
    );
    _epubController.currentValueListenable.addListener(_onPositionChanged);
  }

  /// epub_view only exposes chapter-level counts publicly (`tableOfContents`),
  /// not the total flattened paragraph count it scrolls over internally. Each
  /// chapter's `startIndex` is a flat paragraph index though, so estimating
  /// the last chapter's length from the second-to-last chapter's gives a
  /// reasonable total — enough for a smooth, paragraph-granularity progress
  /// bar instead of the coarse, page-counter-like "chapter N / M".
  int _approxTotalParagraphs() {
    final toc = _epubController.tableOfContents();
    if (toc.isEmpty) return 1;
    if (toc.length == 1) return toc.first.startIndex + 1;
    final last = toc.last.startIndex;
    final secondLast = toc[toc.length - 2].startIndex;
    final avgChapterLength = (last - secondLast).clamp(1, 1 << 30);
    return last + avgChapterLength;
  }

  void _onPositionChanged() {
    final index = _epubController.currentValue?.position.index;
    if (index != null) {
      final total = _approxTotalParagraphs();
      _progressNotifier.value = total > 0 ? (index / total).clamp(0.0, 1.0) : 0;
    }

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () {
      final cfi = _epubController.generateEpubCfi();
      if (cfi != null) widget.onPositionChanged?.call(cfi);
      widget.onProgressChanged?.call(_progressNotifier.value);
    });
  }

  void _seekToRatio(double ratio) {
    final total = _approxTotalParagraphs();
    _epubController.jumpTo(
      index: (ratio.clamp(0.0, 1.0) * total).round().clamp(0, total),
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _epubController.currentValueListenable.removeListener(_onPositionChanged);
    _epubController.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  Future<void> _addBookmark() async {
    final cfi = _epubController.generateEpubCfi();
    if (cfi == null) return;
    final chapterTitle =
        _epubController.currentValue?.chapter?.Title
            ?.replaceAll('\n', '')
            .trim() ??
        widget.title;
    final bookmark = Bookmark(
      id: _uuid.v4(),
      bookId: widget.bookId,
      position: cfi,
      label: chapterTitle,
      createdAt: DateTime.now(),
    );
    await BookmarkStore.add(bookmark);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('bookmark_added'))));
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
    final cfi = result.position;
    if (cfi is String) _epubController.gotoEpubCfi(cfi);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ReadingSettingsController.instance,
      builder: (context, _) {
        final settings = ReadingSettingsController.instance.value;
        final narrow = MediaQuery.of(context).size.width < 480;
        final progressChip = settings.showProgress
            ? ValueListenableBuilder<double>(
                valueListenable: _progressNotifier,
                builder: (context, progress, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: Text('${(progress * 100).round()}%'),
                    ),
                  );
                },
              )
            : null;

        return Scaffold(
          key: _scaffoldKey,
          appBar: glassAppBar(
            context,
            leading: IconButton(
              tooltip: tr('back'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: EpubViewActualChapter(
              controller: _epubController,
              builder: (chapterValue) => Text(
                chapterValue?.chapter?.Title?.replaceAll('\n', '').trim() ??
                    widget.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            actions: narrow
                ? [
                    ?progressChip,
                    IconButton(
                      tooltip: tr('toc'),
                      icon: const Icon(Icons.toc),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'bookmark') _addBookmark();
                        if (v == 'saved') _openSavedItems();
                        if (v == 'settings') showReadingSettingsSheet(context);
                        if (v == 'home') {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        }
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
                        PopupMenuItem(
                          value: 'settings',
                          child: Text(tr('reading_settings')),
                        ),
                        PopupMenuItem(value: 'home', child: Text(tr('home'))),
                      ],
                    ),
                  ]
                : [
                    ?progressChip,
                    IconButton(
                      tooltip: tr('toc'),
                      icon: const Icon(Icons.toc),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
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
                    IconButton(
                      tooltip: tr('reading_settings'),
                      icon: const Icon(Icons.tune),
                      onPressed: () => showReadingSettingsSheet(context),
                    ),
                    IconButton(
                      tooltip: tr('home'),
                      icon: const Icon(Icons.home_outlined),
                      onPressed: () =>
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                    ),
                  ],
          ),
          drawer: Drawer(
            child: EpubViewTableOfContents(controller: _epubController),
          ),
          body: Container(
            color: settings.background.color,
            child: EpubView(
              controller: _epubController,
              builders: EpubViewBuilders<DefaultBuilderOptions>(
                options: DefaultBuilderOptions(
                  textStyle: settings.textStyle,
                  chapterPadding: EdgeInsets.all(settings.pageMargin),
                  paragraphPadding: EdgeInsets.only(
                    left: settings.pageMargin + settings.paragraphIndent,
                    right: settings.pageMargin,
                  ),
                ),
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(tr('epub_open_error', {'error': '$error'})),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: settings.showProgress
              ? SafeArea(
                  child: SizedBox(
                    height: 32,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ValueListenableBuilder<double>(
                        valueListenable: _progressNotifier,
                        builder: (context, progress, _) => SliderTheme(
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
                            value: progress.clamp(0.0, 1.0),
                            onChanged: _seekToRatio,
                          ),
                        ),
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
