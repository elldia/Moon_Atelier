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
import '../widgets/page_jump_row.dart';
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

  // pdfx computes the "current page" from whichever page occupies the most
  // viewport area, which is unreliable right after a large animateToPage
  // jump — most visibly, jumping to the very last page: the content renders
  // correctly, but pagesCount's "most visible" calculation can still report
  // a much earlier page, so the top label and seek bar disagree with what's
  // on screen. Track where we last explicitly jumped to and prefer that
  // until pdfx's own listenable actually reports a (different) value —
  // i.e. until the user scrolls for real.
  int? _pendingJumpPage;

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
    // Don't clear _pendingJumpPage here — pdfx's own listenable can fire
    // with an incorrect value right after a large programmatic jump (not
    // just a stale one), so trusting "any change" would immediately
    // overwrite our override with the wrong number again. Only a genuine
    // user drag/pinch (onInteractionStart, below) should hand control back.
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () {
      final page = _pendingJumpPage ?? _pdfController.pageListenable.value;
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
    final page = _pendingJumpPage ?? _pdfController.pageListenable.value;
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
    if (page is int) _jumpToPage(page, duration: Duration.zero);
  }

  void _seekToRatio(double ratio) {
    final pagesCount = _pdfController.pagesCount;
    if (pagesCount == null || pagesCount <= 0) return;
    _jumpToPage(
      (ratio.clamp(0.0, 1.0) * pagesCount).round(),
      duration: Duration.zero,
    );
  }

  void _jumpToPage(int target, {Duration? duration}) {
    final pagesCount = _pdfController.pagesCount;
    if (pagesCount == null || pagesCount <= 0) return;
    final clamped = target.clamp(1, pagesCount);
    setState(() => _pendingJumpPage = clamped);
    _pdfController.animateToPage(
      pageNumber: clamped,
      duration: duration ?? const Duration(milliseconds: 150),
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
        final page = _pendingJumpPage ?? _pdfController.pageListenable.value;
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
            // A real drag/pinch means the user has taken over navigation —
            // hand display control back from _pendingJumpPage to pdfx's own
            // (now-trustworthy, since it's tracking a live gesture) value.
            onInteractionStart: (_) {
              if (_pendingJumpPage != null) {
                setState(() => _pendingJumpPage = null);
              }
            },
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
                                value: (page / pagesCount).clamp(0.0, 1.0),
                                onChanged: _seekToRatio,
                              ),
                            ),
                          ),
                          if (pagesCount >= 100)
                            Expanded(
                              flex: 3,
                              child: PageJumpRow(
                                onFirst: () => _jumpToPage(1),
                                onBack10: () => _jumpToPage(page - 10),
                                onForward10: () => _jumpToPage(page + 10),
                                onLast: () => _jumpToPage(pagesCount),
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
