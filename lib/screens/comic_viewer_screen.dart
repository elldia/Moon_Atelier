import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../data/bookmark_store.dart';
import '../data/comic_settings_controller.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/bookmark.dart';
import '../models/comic_settings.dart';
import '../utils/comic_archive.dart';
import '../widgets/comic_settings_sheet.dart';
import '../widgets/glass.dart';
import 'saved_items_screen.dart';

const _uuid = Uuid();

/// A comic archive viewer supporting two view modes — single page and
/// two-page spread (pages meeting center-aligned like a real book) — each
/// readable left-to-right or right-to-left — mirroring [PdfViewerScreen]'s
/// bookmarks/progress UX, plus arrow-key navigation and a sharp/medium/
/// smooth image-quality choice.
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

  PageController? _pageController;

  ComicViewMode _mode = ComicViewMode.single;
  ComicReadingDirection _readingDirection = ComicReadingDirection.ltr;

  int _page = 1; // 1-based; the current page (or topmost visible one)
  Timer? _saveDebounce;
  bool _uiVisible = true;
  DateTime? _lastWheelPageTurn;

  int get _spreadCount => (_archive!.pageCount / 2).ceil();

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
    final settings = ComicSettingsController.instance.value;
    _mode = settings.viewMode;
    _readingDirection = settings.readingDirection;
    _initControllers();
    ComicSettingsController.instance.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNeighbors());
  }

  /// Warms Flutter's image cache for the pages just around the current one,
  /// so flipping forward/back usually hits an already-decoded image instead
  /// of decoding synchronously on the frame the new page appears — that
  /// synchronous decode (plus, the first time a given page is visited, the
  /// zip inflate behind [ComicArchive.pageBytes]) is what shows up as a
  /// brief hitch right as a page turn lands.
  void _precacheNeighbors() {
    final archive = _archive;
    if (archive == null || !mounted) {
      return;
    }
    final count = archive.pageCount;
    final current = _page - 1;
    final cacheWidth = _decodeCacheWidth();
    for (final idx in [current - 2, current - 1, current + 1, current + 2]) {
      if (idx < 0 || idx >= count) continue;
      final ImageProvider provider = cacheWidth == null
          ? MemoryImage(archive.pageBytes(idx))
          : ResizeImage(MemoryImage(archive.pageBytes(idx)), width: cacheWidth);
      precacheImage(provider, context);
    }
  }

  void _initControllers() {
    _pageController?.dispose();
    _pageController = null;
    if (_archive == null) return;

    final itemCount = _mode == ComicViewMode.twoPage
        ? _spreadCount
        : _archive!.pageCount;
    final initialIndex = _mode == ComicViewMode.twoPage
        ? (_page - 1) ~/ 2
        : _page - 1;
    _pageController = PageController(
      initialPage: initialIndex.clamp(0, itemCount - 1),
    );
  }

  void _onSettingsChanged() {
    final settings = ComicSettingsController.instance.value;
    if (settings.viewMode == _mode &&
        settings.readingDirection == _readingDirection) {
      setState(() {}); // quality-only change: just repaint with new filter
      return;
    }
    setState(() {
      _mode = settings.viewMode;
      _readingDirection = settings.readingDirection;
      _initControllers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNeighbors());
  }

  @override
  void dispose() {
    ComicSettingsController.instance.removeListener(_onSettingsChanged);
    _saveDebounce?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _persistPosition() {
    widget.onPositionChanged?.call(_page);
    final count = _archive?.pageCount ?? 0;
    if (count > 0) {
      widget.onProgressChanged?.call((_page / count).clamp(0.0, 1.0));
    }
  }

  void _onPageViewChanged(int index) {
    final newPage = _mode == ComicViewMode.twoPage ? index * 2 + 1 : index + 1;
    setState(() => _page = newPage);
    _precacheNeighbors();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _persistPosition);
  }

  void _jumpToPage(int target) {
    final count = _archive?.pageCount ?? 0;
    if (count == 0) return;
    final clamped = target.clamp(1, count);
    final animate = ComicSettingsController.instance.value.animatePageTurns;

    final itemCount = _mode == ComicViewMode.twoPage ? _spreadCount : count;
    final targetIndex =
        (_mode == ComicViewMode.twoPage ? (clamped - 1) ~/ 2 : clamped - 1)
            .clamp(0, itemCount - 1);
    if (animate) {
      _pageController?.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    } else {
      _pageController?.jumpToPage(targetIndex);
    }
    _precacheNeighbors();
  }

  /// Mouse-wheel/trackpad equivalent of the arrow-key page turn. Debounced
  /// so one physical wheel "notch" — which can fire several scroll events
  /// in a browser — turns exactly one page instead of several.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta.abs() < 1) return;
    final now = DateTime.now();
    if (_lastWheelPageTurn != null &&
        now.difference(_lastWheelPageTurn!) <
            const Duration(milliseconds: 180)) {
      return;
    }
    _lastWheelPageTurn = now;
    _jumpToPage(_page + (delta > 0 ? 1 : -1));
  }

  /// Tap-to-turn-page: an edge strip of the content area (sized by
  /// [ComicSettings.tapZoneFraction] along [ComicSettings.tapZoneDirection])
  /// turns to the previous/next page; the remaining middle strip toggles the
  /// reading UI, as a plain tap always used to.
  void _handleContentTap(
    TapUpDetails details,
    Size size,
    ComicSettings settings,
  ) {
    final isHorizontal = settings.tapZoneDirection == ComicDirection.horizontal;
    final extent = isHorizontal ? size.width : size.height;
    if (extent <= 0) return;
    final offset = isHorizontal
        ? details.localPosition.dx
        : details.localPosition.dy;
    final fraction = settings.tapZoneFraction;
    if (offset < extent * fraction) {
      _jumpToPage(_page - 1);
    } else if (offset > extent * (1 - fraction)) {
      _jumpToPage(_page + 1);
    } else {
      setState(() => _uiVisible = !_uiVisible);
    }
  }

  void _handleArrowKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      _jumpToPage(_page + 1);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      _jumpToPage(_page - 1);
    }
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

  Widget _pageImage(
    int index,
    ComicImageQuality quality, {
    Alignment alignment = Alignment.center,
  }) {
    return Align(
      alignment: alignment,
      child: Image.memory(
        _archive!.pageBytes(index),
        fit: BoxFit.contain,
        filterQuality: quality.filterQuality,
        cacheWidth: _decodeCacheWidth(),
      ),
    );
  }

  /// Caps how large Flutter decodes each page image to, based on the
  /// device's own resolution — scanned comic pages routinely run 2-4x a
  /// phone's screen width, and decoding one at full native size only to
  /// immediately downscale it for display wastes decode time and memory
  /// that shows up as slower page turns on big files. Only the width is
  /// capped — height is left to scale to match so [BoxFit.contain]'s aspect
  /// ratio isn't distorted — and Flutter's decoder never upscales past a
  /// source image's native resolution, so this is a no-op for pages
  /// already smaller than the screen.
  int? _decodeCacheWidth() {
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return null;
    final halves = _mode == ComicViewMode.twoPage ? 2 : 1;
    final target = (mq.size.width / halves * mq.devicePixelRatio).round();
    return target > 0 ? target : null;
  }

  Widget _buildPagedView(ComicImageQuality quality) {
    final count = _archive!.pageCount;
    final isTwoPage = _mode == ComicViewMode.twoPage;
    final isRtl = _readingDirection == ComicReadingDirection.rtl;
    return PageView.builder(
      key: ValueKey('${_mode.name}-${_readingDirection.name}'),
      controller: _pageController,
      reverse: isRtl,
      itemCount: isTwoPage ? _spreadCount : count,
      onPageChanged: _onPageViewChanged,
      itemBuilder: (context, index) {
        if (!isTwoPage) return _pageImage(index, quality);
        final firstIdx = index * 2;
        final secondIdx = firstIdx + 1;
        final hasSecond = secondIdx < count;
        // Two-page spreads always turn horizontally and align each page
        // toward the spine in the middle — like a real book, rather than
        // each half independently centering its own page, which can leave
        // a gap when the two pages aren't the same width. In RTL (manga)
        // spreads, the earlier page sits on the right instead of the left.
        final leftPage = isRtl
            ? (hasSecond
                  ? _pageImage(
                      secondIdx,
                      quality,
                      alignment: Alignment.centerRight,
                    )
                  : const SizedBox.shrink())
            : _pageImage(firstIdx, quality, alignment: Alignment.centerRight);
        final rightPage = isRtl
            ? _pageImage(firstIdx, quality, alignment: Alignment.centerLeft)
            : (hasSecond
                  ? _pageImage(
                      secondIdx,
                      quality,
                      alignment: Alignment.centerLeft,
                    )
                  : const SizedBox.shrink());
        return Row(
          children: [
            Expanded(child: leftPage),
            Expanded(child: rightPage),
          ],
        );
      },
    );
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
      animation: Listenable.merge([
        ReadingSettingsController.instance,
        ComicSettingsController.instance,
      ]),
      builder: (context, _) {
        final settings = ReadingSettingsController.instance.value;
        final comicSettings = ComicSettingsController.instance.value;
        final narrow = MediaQuery.of(context).size.width < 420;

        final progressChip = settings.showProgress
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    '$_page / $count · ${((_page / count) * 100).round()}%',
                  ),
                ),
              )
            : const SizedBox.shrink();

        return Scaffold(
          backgroundColor: comicSettings.background.color,
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
                              if (v == 'settings') {
                                showComicSettingsSheet(context);
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
                                child: Text(tr('comic_settings')),
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
                          IconButton(
                            tooltip: tr('comic_settings'),
                            icon: const Icon(Icons.tune),
                            onPressed: () => showComicSettingsSheet(context),
                          ),
                        ],
                ),
          body: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final arrows = {
                LogicalKeyboardKey.arrowLeft,
                LogicalKeyboardKey.arrowRight,
                LogicalKeyboardKey.arrowUp,
                LogicalKeyboardKey.arrowDown,
              };
              if (!arrows.contains(event.logicalKey)) {
                return KeyEventResult.ignored;
              }
              _handleArrowKey(event.logicalKey);
              return KeyEventResult.handled;
            },
            child: Listener(
              onPointerSignal: _handlePointerSignal,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onTapUp: (details) => _handleContentTap(
                    details,
                    constraints.biggest,
                    comicSettings,
                  ),
                  // At the widest tap-zone setting the edge zones can cover
                  // the whole screen, leaving no middle strip to tap for the
                  // UI toggle — long-press always reaches it as a fallback.
                  onLongPress: () => setState(() => _uiVisible = !_uiVisible),
                  child: _buildPagedView(comicSettings.quality),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
