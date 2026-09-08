import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import '../data/bookmark_store.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/bookmark.dart';
import '../widgets/glass.dart';
import 'saved_items_screen.dart';

const _uuid = Uuid();

class PdfViewerScreen extends StatefulWidget {
  final String bookId;
  final String title;
  final Uint8List bytes;
  final int? initialPage;
  final ValueChanged<int>? onPositionChanged;
  final ValueChanged<double>? onProgressChanged;

  const PdfViewerScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.bytes,
    this.initialPage,
    this.onPositionChanged,
    this.onProgressChanged,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // PdfViewPinch (rather than the paged PdfView) gives PDF-only pinch/drag
  // zoom and mouse-wheel zoom for free via pdfx's own InteractiveViewer —
  // no custom gesture handling needed.
  late final PdfControllerPinch _pdfController;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    // pdfx's web backend hands the raw ArrayBuffer to pdf.js's worker as a
    // transferable object, which detaches (zeroes out) the original buffer.
    // Pass a copy so widget.bytes (shared with the persisted Book) stays intact.
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openData(Uint8List.fromList(widget.bytes)),
      initialPage: widget.initialPage ?? 1,
    );
    _pdfController.pageListenable.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () {
      final page = _pdfController.pageListenable.value;
      widget.onPositionChanged?.call(page);
      final pagesCount = _pdfController.pagesCount;
      if (pagesCount != null && pagesCount > 0) {
        widget.onProgressChanged?.call((page / pagesCount).clamp(0.0, 1.0));
      }
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _pdfController.pageListenable.removeListener(_onPageChanged);
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _addBookmark() async {
    final page = _pdfController.pageListenable.value;
    final bookmark = Bookmark(
      id: _uuid.v4(),
      bookId: widget.bookId,
      position: page,
      label: tr('page_n', {'n': '$page'}),
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
    if (page is int) {
      _pdfController.animateToPage(
        pageNumber: page,
        duration: Duration.zero,
        curve: Curves.linear,
      );
    }
  }

  void _seekToRatio(double ratio) {
    final pagesCount = _pdfController.pagesCount;
    if (pagesCount == null || pagesCount <= 0) return;
    _pdfController.animateToPage(
      pageNumber: (ratio.clamp(0.0, 1.0) * pagesCount).round().clamp(
        1,
        pagesCount,
      ),
      duration: Duration.zero,
      curve: Curves.linear,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // pageListenable alone won't fire once the document finishes loading
      // if the page number hasn't changed yet (ValueNotifier only notifies
      // on an actual value change) — merge in loadingState too, so the UI
      // picks up `pagesCount` becoming available right after load.
      animation: Listenable.merge([
        ReadingSettingsController.instance,
        _pdfController.pageListenable,
        _pdfController.loadingState,
      ]),
      builder: (context, _) {
        final settings = ReadingSettingsController.instance.value;
        final narrow = MediaQuery.of(context).size.width < 420;
        final pagesCount = _pdfController.pagesCount;
        final page = _pdfController.pageListenable.value;
        final showBar =
            settings.showProgress && pagesCount != null && pagesCount > 1;

        final progressChip =
            settings.showProgress && pagesCount != null && pagesCount > 0
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    '$page / $pagesCount · ${((page / pagesCount) * 100).round()}%',
                  ),
                ),
              )
            : const SizedBox.shrink();

        return Scaffold(
          appBar: glassAppBar(
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
                        PopupMenuItem(value: 'home', child: Text(tr('home'))),
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
                    IconButton(
                      tooltip: tr('home'),
                      icon: const Icon(Icons.home_outlined),
                      onPressed: () =>
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                    ),
                  ],
          ),
          body: PdfViewPinch(
            controller: _pdfController,
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (context) =>
                  const Center(child: CircularProgressIndicator()),
              pageLoaderBuilder: (context) =>
                  const Center(child: CircularProgressIndicator()),
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tr('pdf_open_error', {'error': '$error'})),
                ),
              ),
            ),
          ),
          floatingActionButton: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'prev',
                onPressed: () => _pdfController.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.ease,
                ),
                child: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.small(
                heroTag: 'next',
                onPressed: () => _pdfController.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.ease,
                ),
                child: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          bottomNavigationBar: showBar
              ? SafeArea(
                  child: SizedBox(
                    height: 32,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          value: (page / pagesCount).clamp(0.0, 1.0),
                          onChanged: _seekToRatio,
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
