import 'dart:async';
import 'dart:typed_data';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/bookmark_store.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/bookmark.dart';
import '../utils/epub_text_extractor.dart';
import '../utils/scroll_ui_visibility.dart';
import '../utils/tts_reader.dart';
import '../widgets/glass.dart';
import '../widgets/page_jump_row.dart';
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

  bool _uiVisible = true;
  late final _uiVisibility = ScrollUiVisibility(
    onChanged: (visible) => setState(() => _uiVisible = visible),
  );

  // epub_view exposes rendering and a flattened paragraph index, but not
  // raw chapter text — independently re-parsed for search/TTS. Chapter
  // granularity (not per-word highlighting) since that's what's cleanly
  // extractable without duplicating epub_view's internal HTML flattening.
  late final _textExtractor = EpubTextExtractor(widget.bytes);

  bool _isSpeaking = false;
  int? _speakingChapter;

  // A hung EPUB parse/load (e.g. a slow network, or a device under memory
  // pressure) previously left the reader stuck on a blank/loading screen
  // forever with no way back except force-closing the tab. Bound it: if
  // loading hasn't finished within this long, show a real error with a way
  // back to the library instead of spinning indefinitely.
  static const _loadTimeoutDuration = Duration(seconds: 30);
  Timer? _loadTimeoutTimer;
  bool _loadTimedOut = false;

  bool _searchActive = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _searchMatches = []; // chapter indices (into tableOfContents())
  int _currentMatchIndex = -1;
  Timer? _searchDebounce;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _epubController = EpubController(
      document: EpubDocument.openData(widget.bytes),
      epubCfi: widget.initialCfi,
    );
    _epubController.currentValueListenable.addListener(_onPositionChanged);
    _loadTimeoutTimer = Timer(_loadTimeoutDuration, () {
      if (!mounted) return;
      if (_epubController.loadingState.value == EpubViewLoadingState.loading) {
        setState(() => _loadTimedOut = true);
      }
    });
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

  // EPUB has no literal "page" either — paragraph index (the same unit
  // _seekToRatio/the progress bar already use) stands in for it, with
  // roughly 10 paragraphs treated as one "page" so "10 pages" reads as a
  // reasonably chapter-scale jump rather than an imperceptible one.
  void _jumpByParagraphs(int delta) {
    final total = _approxTotalParagraphs();
    final currentIndex = _epubController.currentValue?.position.index ?? 0;
    _epubController.jumpTo(index: (currentIndex + delta).clamp(0, total));
  }

  @override
  void dispose() {
    if (_isSpeaking) TtsReader.instance.stop();
    _loadTimeoutTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _saveDebounce?.cancel();
    _epubController.currentValueListenable.removeListener(_onPositionChanged);
    _epubController.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  void _toggleSpeech() {
    if (_isSpeaking) {
      TtsReader.instance.stop();
      setState(() {
        _isSpeaking = false;
        _speakingChapter = null;
      });
      return;
    }
    final toc = _epubController.tableOfContents();
    final currentIndex = _epubController.currentValue?.position.index ?? 0;
    // Start from whichever chapter is currently on screen.
    var startChapter = 0;
    for (var i = 0; i < toc.length; i++) {
      if (toc[i].startIndex <= currentIndex) startChapter = i;
    }
    _speakChapter(startChapter);
  }

  Future<void> _speakChapter(int chapterIndex) async {
    final toc = _epubController.tableOfContents();
    final texts = await _textExtractor.chapterTexts();
    final count = toc.length < texts.length ? toc.length : texts.length;
    if (chapterIndex >= count) {
      setState(() {
        _isSpeaking = false;
        _speakingChapter = null;
      });
      return;
    }
    _epubController.jumpTo(index: toc[chapterIndex].startIndex);
    setState(() {
      _isSpeaking = true;
      _speakingChapter = chapterIndex;
    });
    if (!mounted || !_isSpeaking || _speakingChapter != chapterIndex) return;
    final settings = ReadingSettingsController.instance.value;
    TtsReader.instance.speak(
      texts[chapterIndex],
      rate: settings.ttsRate,
      voice: TtsReader.instance.findVoice(settings.ttsVoiceUri),
      onDone: () {
        if (!mounted || !_isSpeaking) return;
        _speakChapter(chapterIndex + 1);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingChapter = null;
        });
      },
    );
  }

  // Chapter counts run into the tens/low hundreds even for large books (not
  // thousands, unlike TXT's paragraph chunks), so a debounced but otherwise
  // synchronous scan over already-extracted chapter text is fast enough
  // without needing TXT's time-sliced batching.
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
    final texts = await _textExtractor.chapterTexts();
    if (token != _searchToken) return;
    final lowerQuery = query.toLowerCase();
    final matches = [
      for (var i = 0; i < texts.length; i++)
        if (texts[i].toLowerCase().contains(lowerQuery)) i,
    ];
    if (!mounted || token != _searchToken) return;
    setState(() {
      _searchQuery = query;
      _searchMatches = matches;
      _currentMatchIndex = matches.isEmpty ? -1 : 0;
    });
    if (_currentMatchIndex >= 0) _jumpToMatch(_currentMatchIndex);
  }

  void _jumpToMatch(int matchIndex) {
    if (matchIndex < 0 || matchIndex >= _searchMatches.length) return;
    setState(() => _currentMatchIndex = matchIndex);
    final toc = _epubController.tableOfContents();
    final chapterIndex = _searchMatches[matchIndex];
    if (chapterIndex < toc.length) {
      _epubController.jumpTo(index: toc[chapterIndex].startIndex);
    }
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
    final cfi = result.position;
    if (cfi is String) _epubController.gotoEpubCfi(cfi);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadTimedOut) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(tr('load_timeout'), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(tr('load_timeout_back')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      // _approxTotalParagraphs() (and so the 100+"page" jump row's
      // visibility) depends on the table of contents, which isn't
      // necessarily populated yet on the very first build — merging in
      // currentValueListenable makes that recheck itself on every position
      // update instead of being frozen at whatever it evaluated to before
      // the book finished loading.
      animation: Listenable.merge([
        ReadingSettingsController.instance,
        _epubController.currentValueListenable,
      ]),
      builder: (context, _) {
        final settings = ReadingSettingsController.instance.value;
        // 6 standalone action icons (toc/TTS/bookmark/saved/settings/search)
        // plus the chapter-title text and progress chip don't comfortably
        // fit until quite wide — verified the last icon (search) pushed off
        // the visible app bar entirely at 1280px width. The other viewers'
        // breakpoints (420-480) work because they have 1-2 fewer icons;
        // EPUB's extra "toc" icon needs a noticeably higher one.
        final narrow = MediaQuery.of(context).size.width < 1300;
        final progressChip = settings.showProgress
            ? ValueListenableBuilder<double>(
                valueListenable: _progressNotifier,
                builder: (context, progress, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(child: Text('${(progress * 100).round()}%')),
                  );
                },
              )
            : null;

        return Scaffold(
          key: _scaffoldKey,
          appBar: !_uiVisible
              ? null
              : glassAppBar(
                  context,
                  leading: IconButton(
                    tooltip: tr('back'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
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
                      : EpubViewActualChapter(
                          controller: _epubController,
                          builder: (chapterValue) => Text(
                            chapterValue?.chapter?.Title
                                    ?.replaceAll('\n', '')
                                    .trim() ??
                                widget.title,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                          ?progressChip,
                          IconButton(
                            tooltip: tr('toc'),
                            icon: const Icon(Icons.toc),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'tts') _toggleSpeech();
                              if (v == 'bookmark') _addBookmark();
                              if (v == 'saved') _openSavedItems();
                              if (v == 'settings')
                                showReadingSettingsSheet(context);
                              if (v == 'search') {
                                setState(() {
                                  _searchActive = true;
                                  _uiVisible = true;
                                });
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
                              PopupMenuItem(
                                value: 'settings',
                                child: Text(tr('reading_settings')),
                              ),
                              PopupMenuItem(
                                value: 'search',
                                child: Text(tr('search')),
                              ),
                            ],
                          ),
                        ]
                      : [
                          ?progressChip,
                          IconButton(
                            tooltip: tr('toc'),
                            icon: const Icon(Icons.toc),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                          IconButton(
                            tooltip: _isSpeaking
                                ? tr('tts_stop')
                                : tr('tts_start'),
                            icon: Icon(
                              _isSpeaking
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                            ),
                            onPressed: _toggleSpeech,
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
                            tooltip: tr('search'),
                            icon: const Icon(Icons.search),
                            onPressed: () => setState(() {
                              _searchActive = true;
                              _uiVisible = true;
                            }),
                          ),
                        ],
                ),
          drawer: Drawer(
            child: EpubViewTableOfContents(controller: _epubController),
          ),
          body: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _uiVisibility.show(),
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                // Scrolling through search results shouldn't hide the app
                // bar — closing search (the X button) is what hands control
                // back to the normal scroll-hide behavior.
                if (n.scrollDelta != null && !_searchActive) {
                  _uiVisibility.feed(n.scrollDelta!);
                }
                return false;
              },
              child: Container(
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
                    loaderBuilder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: settings.showProgress && _uiVisible
              ? SafeArea(
                  child: SizedBox(
                    height: 36,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 7,
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
                          if (_approxTotalParagraphs() >= 1000)
                            Expanded(
                              flex: 3,
                              child: PageJumpRow(
                                onFirst: () => _epubController.jumpTo(index: 0),
                                onBack10: () => _jumpByParagraphs(-100),
                                onForward10: () => _jumpByParagraphs(100),
                                onLast: () => _epubController.jumpTo(
                                  index: _approxTotalParagraphs(),
                                ),
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
