import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/bookmark_store.dart';
import '../data/highlight_store.dart';
import '../data/reading_settings_controller.dart';
import '../models/bookmark.dart';
import '../models/highlight.dart';
import '../l10n/strings.dart';
import '../models/reading_settings.dart';
import '../widgets/glass.dart';
import '../utils/scroll_ui_visibility.dart';
import '../utils/tts_reader.dart';
import '../widgets/page_jump_row.dart';
import '../widgets/reading_settings_sheet.dart';
import 'saved_items_screen.dart';

const _uuid = Uuid();

/// Max characters per rendered chunk. A single multi-megabyte string handed to
/// one Text/SelectableText widget can overwhelm the web text-layout engine on
/// very large files (a 4MB+ novel crashes CanvasKit), so long content is split
/// into bounded chunks and rendered in a virtualized, lazily-built list.
const _maxChunkLength = 2000;

/// Shared plain-text reader used for .txt, .docx and .rtf (post-extraction)
/// content. Font, spacing, margins, indent, background and theme all come
/// from the shared [ReadingSettingsController] so they stay in sync with the
/// library screen and update live while reading. Also supports selecting a
/// sentence to save as a highlighted quote, and bookmarking the current
/// position — both scoped to [bookId] and persisted independently of the
/// book's own last-read position.
class TextViewerScreen extends StatefulWidget {
  final String bookId;
  final String title;
  final String content;
  final double? initialOffset;
  final ValueChanged<double>? onPositionChanged;
  final ValueChanged<double>? onProgressChanged;

  const TextViewerScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.content,
    this.initialOffset,
    this.onPositionChanged,
    this.onProgressChanged,
  });

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  final _scrollController = ScrollController();
  final _progressNotifier = ValueNotifier<double>(0);
  Timer? _saveDebounce;
  late final List<String> _chunks;
  final Map<int, List<Highlight>> _highlightsByChunk = {};

  bool _uiVisible = true;
  double? _lastScrollPixels;
  late final _uiVisibility = ScrollUiVisibility(
    onChanged: (visible) => setState(() => _uiVisible = visible),
  );

  bool _isSpeaking = false;
  int? _speakingChunkIndex;

  static const _searchMinContentLength = 1000;
  bool _searchActive = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<(int chunkIndex, int start)> _searchMatches = [];
  int _currentMatchIndex = -1;

  int? _selectedChunkIndex;
  TextSelection? _selection;
  Color _pendingHighlightColor = Highlight.defaultColor;

  static const _highlightColors = [
    Highlight.defaultColor,
    Color(0x664CAF50),
    Color(0x66FF80AB),
    Color(0x6664B5F6),
    Color(0x66FFB74D),
  ];

  @override
  void initState() {
    super.initState();
    _chunks = _splitIntoChunks(widget.content);
    _loadHighlights();

    final offset = widget.initialOffset;
    if (offset != null && offset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final target = offset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(target);
      });
    }
    _scrollController.addListener(_onScroll);
  }

  void _loadHighlights() {
    _highlightsByChunk.clear();
    for (final h in HighlightStore.forBook(widget.bookId)) {
      _highlightsByChunk.putIfAbsent(h.chunkIndex, () => []).add(h);
    }
  }

  static List<String> _splitIntoChunks(String content) {
    if (content.isEmpty) return const [];
    final chunks = <String>[];
    for (final paragraph in content.split('\n')) {
      if (paragraph.length <= _maxChunkLength) {
        chunks.add(paragraph);
        continue;
      }
      for (var i = 0; i < paragraph.length; i += _maxChunkLength) {
        chunks.add(
          paragraph.substring(
            i,
            (i + _maxChunkLength).clamp(0, paragraph.length),
          ),
        );
      }
    }
    return chunks;
  }

  void _onScroll() {
    final position = _scrollController.position;
    _progressNotifier.value = position.maxScrollExtent <= 0
        ? 1
        : (position.pixels / position.maxScrollExtent).clamp(0, 1);

    final last = _lastScrollPixels;
    if (last != null) _uiVisibility.feed(position.pixels - last);
    _lastScrollPixels = position.pixels;

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () {
      widget.onPositionChanged?.call(_scrollController.offset);
      widget.onProgressChanged?.call(_progressNotifier.value);
    });
  }

  void _onSelectionChanged(int index, TextSelection selection) {
    setState(() {
      if (selection.isCollapsed) {
        if (_selectedChunkIndex == index) {
          _selectedChunkIndex = null;
          _selection = null;
        }
      } else {
        _selectedChunkIndex = index;
        _selection = selection;
      }
    });
  }

  Future<void> _saveHighlight() async {
    final index = _selectedChunkIndex;
    final selection = _selection;
    if (index == null || selection == null) return;
    final chunk = _chunks[index];
    final start = selection.start.clamp(0, chunk.length);
    final end = selection.end.clamp(0, chunk.length);
    if (end <= start) return;

    final highlight = Highlight(
      id: _uuid.v4(),
      bookId: widget.bookId,
      chunkIndex: index,
      start: start,
      end: end,
      text: chunk.substring(start, end),
      color: _pendingHighlightColor,
      createdAt: DateTime.now(),
    );
    await HighlightStore.add(highlight);
    if (!mounted) return;
    setState(() {
      _highlightsByChunk.putIfAbsent(index, () => []).add(highlight);
      _selectedChunkIndex = null;
      _selection = null;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedChunkIndex = null;
      _selection = null;
    });
  }

  String _previewNear(double offset) {
    if (_chunks.isEmpty) return tr('empty_document');
    final maxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final ratio = maxExtent > 0 ? (offset / maxExtent).clamp(0.0, 1.0) : 0.0;
    final idx = (ratio * (_chunks.length - 1)).round().clamp(
      0,
      _chunks.length - 1,
    );
    for (var i = idx; i < _chunks.length; i++) {
      final text = _chunks[i].trim();
      if (text.isNotEmpty) {
        return text.length > 28 ? '${text.substring(0, 28)}…' : text;
      }
    }
    return tr('empty_paragraph');
  }

  Future<void> _addBookmark() async {
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final bookmark = Bookmark(
      id: _uuid.v4(),
      bookId: widget.bookId,
      position: offset,
      label: _previewNear(offset),
      createdAt: DateTime.now(),
    );
    await BookmarkStore.add(bookmark);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('bookmark_added'))));
  }

  void _seekToRatio(double ratio) {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(
      ratio.clamp(0.0, 1.0) * _scrollController.position.maxScrollExtent,
    );
  }

  // TXT/DOCX/RTF have no literal "page" concept — chunks (already shown in
  // the app bar as "current / total", the same paging-like indicator PDF
  // uses) stand in for pages here, so "10 pages" means 10 chunks.
  void _jumpByChunks(int delta) {
    if (_chunks.length <= 1) return;
    final currentChunk = (_progressNotifier.value * (_chunks.length - 1))
        .round();
    final target = (currentChunk + delta).clamp(0, _chunks.length - 1);
    _seekToRatio(target / (_chunks.length - 1));
  }

  Future<void> _openSavedItems() async {
    final result = await Navigator.of(context).push<SavedItemJump>(
      MaterialPageRoute(
        builder: (_) =>
            SavedItemsScreen(bookId: widget.bookId, bookTitle: widget.title),
      ),
    );
    if (result == null || !mounted || !_scrollController.hasClients) return;

    double? target;
    final chunkIndex = result.chunkIndex;
    final position = result.position;
    if (chunkIndex != null && _chunks.length > 1) {
      final ratio = chunkIndex / (_chunks.length - 1);
      target = ratio * _scrollController.position.maxScrollExtent;
    } else if (position is num) {
      target = position.toDouble();
    }
    if (target == null) return;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _toggleSpeech() {
    if (_isSpeaking) {
      TtsReader.instance.stop();
      setState(() {
        _isSpeaking = false;
        _speakingChunkIndex = null;
      });
      return;
    }
    // Start from whichever chunk is currently on screen, not necessarily
    // chunk 0 — reading aloud should pick up where the reader already is.
    final startIndex = _chunks.isEmpty
        ? 0
        : (_progressNotifier.value * (_chunks.length - 1)).round().clamp(
            0,
            _chunks.length - 1,
          );
    _speakChunk(startIndex);
  }

  void _speakChunk(int index) {
    if (index >= _chunks.length) {
      setState(() {
        _isSpeaking = false;
        _speakingChunkIndex = null;
      });
      return;
    }
    if (_chunks.length > 1) _seekToRatio(index / (_chunks.length - 1));
    setState(() {
      _isSpeaking = true;
      _speakingChunkIndex = index;
    });
    TtsReader.instance.speak(
      _chunks[index],
      onDone: () {
        if (!mounted || !_isSpeaking) return;
        _speakChunk(index + 1);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingChunkIndex = null;
        });
      },
    );
  }

  List<int> _matchStartsInChunk(int chunkIndex) => [
    for (final m in _searchMatches)
      if (m.$1 == chunkIndex) m.$2,
  ];

  void _runSearch(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      setState(() {
        _searchMatches = [];
        _currentMatchIndex = -1;
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    final matches = <(int, int)>[];
    for (var i = 0; i < _chunks.length; i++) {
      final lowerChunk = _chunks[i].toLowerCase();
      var start = 0;
      while (true) {
        final idx = lowerChunk.indexOf(lowerQuery, start);
        if (idx < 0) break;
        matches.add((i, idx));
        start = idx + lowerQuery.length;
      }
    }
    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = matches.isEmpty ? -1 : 0;
    });
    if (_currentMatchIndex >= 0) _jumpToMatch(_currentMatchIndex);
  }

  void _jumpToMatch(int matchIndex) {
    if (matchIndex < 0 || matchIndex >= _searchMatches.length) return;
    final (chunkIndex, _) = _searchMatches[matchIndex];
    if (_chunks.length > 1) _seekToRatio(chunkIndex / (_chunks.length - 1));
    setState(() => _currentMatchIndex = matchIndex);
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
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchMatches = [];
      _currentMatchIndex = -1;
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    if (_isSpeaking) TtsReader.instance.stop();
    _searchController.dispose();
    _saveDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  List<Widget> _buildAppBarActions(ReadingSettings settings) {
    final progressChip = settings.showProgress && _chunks.isNotEmpty
        ? ValueListenableBuilder<double>(
            valueListenable: _progressNotifier,
            builder: (context, progress, _) {
              final current = (progress * (_chunks.length - 1)).round() + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(child: Text('$current / ${_chunks.length}')),
              );
            },
          )
        : null;

    final narrow = MediaQuery.of(context).size.width < 480;
    if (narrow) {
      return [
        ?progressChip,
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'tts') _toggleSpeech();
            if (v == 'bookmark') _addBookmark();
            if (v == 'saved') _openSavedItems();
            if (v == 'settings') showReadingSettingsSheet(context);
            if (v == 'search') setState(() => _searchActive = true);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'tts',
              child: Text(_isSpeaking ? tr('tts_stop') : tr('tts_start')),
            ),
            PopupMenuItem(value: 'bookmark', child: Text(tr('bookmark_add'))),
            PopupMenuItem(
              value: 'saved',
              child: Text(tr('bookmark_saved_list')),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Text(tr('reading_settings')),
            ),
            if (widget.content.length >= _searchMinContentLength)
              PopupMenuItem(value: 'search', child: Text(tr('search'))),
          ],
        ),
      ];
    }
    return [
      ?progressChip,
      IconButton(
        tooltip: _isSpeaking ? tr('tts_stop') : tr('tts_start'),
        icon: Icon(
          _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
        ),
        onPressed: _chunks.isEmpty ? null : _toggleSpeech,
      ),
      IconButton(
        tooltip: tr('bookmark_add'),
        icon: const Icon(Icons.bookmark_add_outlined),
        onPressed: _addBookmark,
      ),
      IconButton(
        tooltip: tr('bookmark_saved_list'),
        icon: const Icon(Icons.bookmarks_outlined),
        onPressed: _openSavedItems,
      ),
      IconButton(
        tooltip: tr('reading_settings'),
        icon: const Icon(Icons.tune),
        onPressed: () => showReadingSettingsSheet(context),
      ),
      if (widget.content.length >= _searchMinContentLength)
        IconButton(
          tooltip: tr('search'),
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searchActive = true),
        ),
    ];
  }

  Widget _buildChunk(int index, String chunk, ReadingSettings settings) {
    // Merge saved highlights and (if a search is active) match ranges into
    // one sorted, non-overlapping decoration list so both render correctly
    // together instead of needing two separate splitting passes.
    final decorations = <(int start, int end, TextStyle style)>[
      for (final h in _highlightsByChunk[index] ?? const <Highlight>[])
        if (h.end.clamp(0, chunk.length) > h.start.clamp(0, chunk.length))
          (
            h.start.clamp(0, chunk.length),
            h.end.clamp(0, chunk.length),
            TextStyle(backgroundColor: h.color),
          ),
      if (_searchQuery.isNotEmpty)
        for (final start in _matchStartsInChunk(index))
          if ((start + _searchQuery.length).clamp(0, chunk.length) > start)
            (
              start,
              (start + _searchQuery.length).clamp(0, chunk.length),
              TextStyle(
                backgroundColor:
                    _searchMatches.isNotEmpty &&
                        _currentMatchIndex >= 0 &&
                        _searchMatches[_currentMatchIndex] == (index, start)
                    ? const Color(0xCCFF9800)
                    : const Color(0x66FF9800),
              ),
            ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final spans = <InlineSpan>[
      if (settings.paragraphIndent > 0)
        WidgetSpan(child: SizedBox(width: settings.paragraphIndent)),
    ];
    var cursor = 0;
    for (final (start, end, style) in decorations) {
      if (end <= cursor) continue;
      if (start > cursor)
        spans.add(TextSpan(text: chunk.substring(cursor, start)));
      spans.add(
        TextSpan(
          text: chunk.substring(start.clamp(cursor, chunk.length), end),
          style: style,
        ),
      );
      cursor = end;
    }
    if (cursor < chunk.length)
      spans.add(TextSpan(text: chunk.substring(cursor)));

    return SelectableText.rich(
      TextSpan(children: spans),
      style: settings.textStyle,
      onSelectionChanged: (selection, cause) =>
          _onSelectionChanged(index, selection),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ReadingSettingsController.instance,
      builder: (context, _) {
        final settings = ReadingSettingsController.instance.value;
        return Scaffold(
          backgroundColor: settings.background.color,
          appBar: _uiVisible
              ? glassAppBar(
                  context,
                  title: _searchActive
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: tr('content_search_hint'),
                            border: InputBorder.none,
                          ),
                          onChanged: _runSearch,
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
                      : _buildAppBarActions(settings),
                )
              : null,
          body: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _uiVisibility.show(),
            child: _chunks.isEmpty
                ? Center(child: Text(tr('content_not_found')))
                : Stack(
                    children: [
                      TextSelectionTheme(
                        // A vivid, theme-independent color so an in-progress
                        // drag selection is unmistakably visible against any
                        // reading background (default selection tinting can
                        // be too subtle, especially on sepia/dark).
                        data: const TextSelectionThemeData(
                          selectionColor: Color(0x66FF6D00),
                        ),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(settings.pageMargin),
                          itemCount: _chunks.length,
                          itemBuilder: (context, index) {
                            final chunk = _chunks[index];
                            if (chunk.isEmpty) {
                              return const SizedBox(height: 16);
                            }
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.only(bottom: 12),
                              color: index == _speakingChunkIndex
                                  ? settings.background.textColor.withValues(
                                      alpha: 0.08,
                                    )
                                  : null,
                              child: _buildChunk(index, chunk, settings),
                            );
                          },
                        ),
                      ),
                      if (_selectedChunkIndex != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: SafeArea(
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.border_color,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            tr('save_selection_prompt'),
                                          ),
                                        ),
                                        for (final color in _highlightColors)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                            ),
                                            child: InkWell(
                                              onTap: () => setState(
                                                () => _pendingHighlightColor =
                                                    color,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: Color(
                                                    0xFF000000 |
                                                        color.toARGB32(),
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        _pendingHighlightColor ==
                                                            color
                                                        ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                        : Colors.transparent,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: _cancelSelection,
                                          child: Text(tr('cancel')),
                                        ),
                                        TextButton(
                                          onPressed: _saveHighlight,
                                          child: Text(tr('save_as_highlight')),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          bottomNavigationBar:
              settings.showProgress && _chunks.length > 1 && _uiVisible
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
                          if (_chunks.length >= 100)
                            Expanded(
                              flex: 3,
                              child: PageJumpRow(
                                onFirst: () => _seekToRatio(0),
                                onBack10: () => _jumpByChunks(-10),
                                onForward10: () => _jumpByChunks(10),
                                onLast: () => _seekToRatio(1),
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
