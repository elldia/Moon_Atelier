import 'dart:async';

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
import '../widgets/page_jump_row.dart';
import 'saved_items_screen.dart';

const _uuid = Uuid();

/// A comic archive viewer supporting three view modes (single page, two-page
/// spread, continuous scroll) each combinable with either page-turn/scroll
/// direction (horizontal/vertical) — mirroring [PdfViewerScreen]'s
/// bookmarks/progress UX, plus arrow-key navigation and a
/// sharp/medium/smooth image-quality choice.
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

  PageController? _pageController; // single / twoPage modes
  ScrollController? _scrollController; // continuousScroll mode

  ComicViewMode _mode = ComicViewMode.single;
  ComicDirection _direction = ComicDirection.horizontal;

  int _page = 1; // 1-based; the current page (or topmost visible one)
  Timer? _saveDebounce;
  bool _uiVisible = true;

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
    _direction = settings.direction;
    _initControllers();
    ComicSettingsController.instance.addListener(_onSettingsChanged);
  }

  void _initControllers() {
    _pageController?.dispose();
    _pageController = null;
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    _scrollController = null;
    if (_archive == null) return;

    if (_mode == ComicViewMode.continuousScroll) {
      _scrollController = ScrollController();
      _scrollController!.addListener(_onScroll);
      if (_page > 1) {
        final targetPage = _page;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToPageRatio(targetPage, animate: false),
        );
      }
    } else {
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
  }

  void _onSettingsChanged() {
    final settings = ComicSettingsController.instance.value;
    if (settings.viewMode == _mode && settings.direction == _direction) {
      setState(() {}); // quality-only change: just repaint with new filter
      return;
    }
    setState(() {
      _mode = settings.viewMode;
      _direction = settings.direction;
      _initControllers();
    });
  }

  /// Scrolls to the position [page] would occupy if every page shared an
  /// equal fraction of the total scrollable extent. Comic pages are rarely
  /// identical sizes, so this is an approximation — but it needs no
  /// RenderObject introspection (each page's real on-screen extent isn't
  /// known until Flutter lays it out, and only nearby pages are ever built
  /// at once in a lazy list), and it self-corrects as the user keeps
  /// scrolling for real.
  void _scrollToPageRatio(int page, {required bool animate}) {
    final controller = _scrollController;
    if (!mounted || controller == null || !controller.hasClients) return;
    final count = _archive?.pageCount ?? 0;
    if (count <= 1) return;
    final maxExtent = controller.position.maxScrollExtent;
    final target = (maxExtent * (page - 1) / (count - 1)).clamp(0.0, maxExtent);
    if (animate) {
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
      );
    } else {
      controller.jumpTo(target);
    }
  }

  @override
  void dispose() {
    ComicSettingsController.instance.removeListener(_onSettingsChanged);
    _saveDebounce?.cancel();
    _pageController?.dispose();
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
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
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _persistPosition);
  }

  void _onScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () {
      final page = _estimatePageFromOffset();
      if (page != null && page != _page) setState(() => _page = page);
      _persistPosition();
    });
  }

  /// The inverse of [_scrollToPageRatio]'s mapping: which page the current
  /// scroll offset's fraction of the total extent corresponds to.
  int? _estimatePageFromOffset() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return null;
    final count = _archive?.pageCount ?? 0;
    if (count <= 1) return count == 1 ? 1 : null;
    final maxExtent = controller.position.maxScrollExtent;
    if (maxExtent <= 0) return 1;
    final ratio = (controller.offset / maxExtent).clamp(0.0, 1.0);
    return (ratio * (count - 1)).round() + 1;
  }

  void _jumpToPage(int target) {
    final count = _archive?.pageCount ?? 0;
    if (count == 0) return;
    final clamped = target.clamp(1, count);

    if (_mode == ComicViewMode.continuousScroll) {
      _scrollToPageRatio(clamped, animate: true);
      setState(() => _page = clamped);
      _saveDebounce?.cancel();
      _saveDebounce = Timer(
        const Duration(milliseconds: 300),
        _persistPosition,
      );
      return;
    }

    final itemCount = _mode == ComicViewMode.twoPage ? _spreadCount : count;
    final targetIndex = _mode == ComicViewMode.twoPage
        ? (clamped - 1) ~/ 2
        : clamped - 1;
    _pageController?.animateToPage(
      targetIndex.clamp(0, itemCount - 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
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

  Widget _pageImage(int index, ComicImageQuality quality) {
    return InteractiveViewer(
      maxScale: 4,
      child: Center(
        child: Image.memory(
          _archive!.pageBytes(index),
          fit: BoxFit.contain,
          filterQuality: quality.filterQuality,
        ),
      ),
    );
  }

  Widget _buildPagedView(ComicImageQuality quality) {
    final count = _archive!.pageCount;
    final isTwoPage = _mode == ComicViewMode.twoPage;
    return PageView.builder(
      key: ValueKey('${_mode.name}-${_direction.name}'),
      controller: _pageController,
      scrollDirection: _direction.axis,
      itemCount: isTwoPage ? _spreadCount : count,
      onPageChanged: _onPageViewChanged,
      itemBuilder: (context, index) {
        if (!isTwoPage) return _pageImage(index, quality);
        final firstIdx = index * 2;
        final secondIdx = firstIdx + 1;
        final children = [
          Expanded(child: _pageImage(firstIdx, quality)),
          Expanded(
            child: secondIdx < count
                ? _pageImage(secondIdx, quality)
                : const SizedBox.shrink(),
          ),
        ];
        return _direction == ComicDirection.horizontal
            ? Row(children: children)
            : Column(children: children);
      },
    );
  }

  Widget _buildContinuousScroll(ComicImageQuality quality, BuildContext context) {
    final isVertical = _direction == ComicDirection.vertical;
    final size = MediaQuery.sizeOf(context);
    final images = [
      for (var index = 0; index < _archive!.pageCount; index++)
        isVertical
            ? Image.memory(
                _archive!.pageBytes(index),
                width: size.width,
                fit: BoxFit.fitWidth,
                filterQuality: quality.filterQuality,
              )
            : Image.memory(
                _archive!.pageBytes(index),
                height: size.height,
                fit: BoxFit.fitHeight,
                filterQuality: quality.filterQuality,
              ),
    ];
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      child: isVertical
          ? Column(mainAxisSize: MainAxisSize.min, children: images)
          : Row(mainAxisSize: MainAxisSize.min, children: images),
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
        final showBar = settings.showProgress && count > 1;

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
            child: GestureDetector(
              onTap: () => setState(() => _uiVisible = !_uiVisible),
              child: comicSettings.viewMode == ComicViewMode.continuousScroll
                  ? _buildContinuousScroll(comicSettings.quality, context)
                  : _buildPagedView(comicSettings.quality),
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
