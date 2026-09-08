import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import '../data/bookmark_store.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/bookmark.dart';
import '../utils/pdf_text_extractor.dart';
import '../utils/scroll_ui_visibility.dart';
import '../utils/tts_reader.dart';
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

  bool _uiVisible = true;
  late final _uiVisibility = ScrollUiVisibility(
    onChanged: (visible) => setState(() => _uiVisible = visible),
  );

  // pdfx only rasterizes pages to images (no text layer), so page text for
  // search/TTS is pulled independently from a second, private pdf.js
  // document opened on the same bytes — see PdfTextExtractor.
  late final _textExtractor = PdfTextExtractor(widget.bytes);

  bool _isSpeaking = false;
  int? _speakingPage;

  bool _searchActive = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _searchMatches = []; // page numbers (1-based) containing a hit
  int _currentMatchIndex = -1;
  Timer? _searchDebounce;
  int _searchToken = 0;

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
    if (_isSpeaking) TtsReader.instance.stop();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _textExtractor.dispose();
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

  void _toggleSpeech() {
    if (_isSpeaking) {
      TtsReader.instance.stop();
      setState(() {
        _isSpeaking = false;
        _speakingPage = null;
      });
      return;
    }
    _speakPage(_pendingJumpPage ?? _pdfController.pageListenable.value);
  }

  Future<void> _speakPage(int page) async {
    final pagesCount = _pdfController.pagesCount;
    if (pagesCount == null || page > pagesCount) {
      setState(() {
        _isSpeaking = false;
        _speakingPage = null;
      });
      return;
    }
    _jumpToPage(page, duration: Duration.zero);
    setState(() {
      _isSpeaking = true;
      _speakingPage = page;
    });
    final text = await _textExtractor.extractPageText(page);
    if (!mounted || !_isSpeaking || _speakingPage != page) return;
    final settings = ReadingSettingsController.instance.value;
    TtsReader.instance.speak(
      text,
      rate: settings.ttsRate,
      voice: TtsReader.instance.findVoice(settings.ttsVoiceUri),
      onDone: () {
        if (!mounted || !_isSpeaking) return;
        _speakPage(page + 1);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingPage = null;
        });
      },
    );
  }

  // Debounce the trigger and yield between pages (each extractPageText call
  // is already async/awaited, so this naturally can't block the UI thread
  // the way a synchronous full-book scan could).
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      _searchToken++;
      setState(() {
        _searchQuery = '';
        _searchMatches = [];
        _currentMatchIndex = -1;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    final pagesCount = _pdfController.pagesCount;
    if (pagesCount == null || pagesCount <= 0) return;
    final matches = <int>[];
    setState(() {
      _searchQuery = query;
      _searchMatches = matches;
      _currentMatchIndex = -1;
    });
    final lowerQuery = query.toLowerCase();
    for (var page = 1; page <= pagesCount; page++) {
      if (token != _searchToken) return; // a newer search took over
      final text = await _textExtractor.extractPageText(page);
      if (token != _searchToken) return;
      if (text.toLowerCase().contains(lowerQuery)) {
        matches.add(page);
        if (!mounted) return;
        setState(() {});
      }
    }
    if (!mounted || token != _searchToken) return;
    setState(() => _currentMatchIndex = matches.isEmpty ? -1 : 0);
    if (_currentMatchIndex >= 0) _jumpToMatch(_currentMatchIndex);
  }

  void _jumpToMatch(int matchIndex) {
    if (matchIndex < 0 || matchIndex >= _searchMatches.length) return;
    setState(() => _currentMatchIndex = matchIndex);
    _jumpToPage(_searchMatches[matchIndex], duration: Duration.zero);
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    _jumpToMatch((_currentMatchIndex + 1) % _searchMatches.length);
  }

  void _prevMatch() {
    if (_searchMatches.isEmpty) return;
    _jumpToMatch(
      (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length,
    );
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchToken++;
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchMatches = [];
      _currentMatchIndex = -1;
      _searchController.clear();
    });
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
          appBar: !_uiVisible
              ? null
              : glassAppBar(
                  context,
                  title: _searchActive
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: tr('content_search_hint'),
                            border: InputBorder.none,
                          ),
                          onChanged: _onSearchChanged,
                        )
                      : Text(widget.title, overflow: TextOverflow.ellipsis),
                  leading: IconButton(
                    tooltip: tr('back'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  actions: _searchActive
                      ? [
                          if (_searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Center(
                                child: Text(
                                  _searchMatches.isEmpty
                                      ? '0/0'
                                      : '${_currentMatchIndex + 1}/${_searchMatches.length}',
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: tr('search_prev'),
                            icon: const Icon(Icons.keyboard_arrow_up),
                            onPressed: _searchMatches.isEmpty
                                ? null
                                : _prevMatch,
                          ),
                          IconButton(
                            tooltip: tr('search_next'),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: _searchMatches.isEmpty
                                ? null
                                : _nextMatch,
                          ),
                          IconButton(
                            tooltip: tr('close_search'),
                            icon: const Icon(Icons.close),
                            onPressed: _closeSearch,
                          ),
                        ]
                      : narrow
                      ? [
                          progressChip,
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'tts') _toggleSpeech();
                              if (v == 'bookmark') _addBookmark();
                              if (v == 'saved') _openSavedItems();
                              if (v == 'search') {
                                setState(() => _searchActive = true);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'tts',
                                child: Text(
                                  _isSpeaking
                                      ? tr('tts_stop')
                                      : tr('tts_start'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'bookmark',
                                child: Text(tr('bookmark_add')),
                              ),
                              PopupMenuItem(
                                value: 'saved',
                                child: Text(tr('bookmark_list')),
                              ),
                              if (pagesCount != null && pagesCount > 0)
                                PopupMenuItem(
                                  value: 'search',
                                  child: Text(tr('search')),
                                ),
                            ],
                          ),
                        ]
                      : [
                          progressChip,
                          IconButton(
                            tooltip: _isSpeaking
                                ? tr('tts_stop')
                                : tr('tts_start'),
                            icon: Icon(
                              _isSpeaking
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                            ),
                            onPressed: pagesCount == null || pagesCount == 0
                                ? null
                                : _toggleSpeech,
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
                          if (pagesCount != null && pagesCount > 0)
                            IconButton(
                              tooltip: tr('search'),
                              icon: const Icon(Icons.search),
                              onPressed: () =>
                                  setState(() => _searchActive = true),
                            ),
                        ],
                ),
          body: PdfViewPinch(
            controller: _pdfController,
            // A real drag/pinch means the user has taken over navigation —
            // hand display control back from _pendingJumpPage to pdfx's own
            // (now-trustworthy, since it's tracking a live gesture) value.
            onInteractionStart: (_) {
              _uiVisibility.show();
              if (_pendingJumpPage != null) {
                setState(() => _pendingJumpPage = null);
              }
            },
            onInteractionUpdate: (details) =>
                _uiVisibility.feed(-details.focalPointDelta.dy),
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
