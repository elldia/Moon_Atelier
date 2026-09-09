import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:uuid/uuid.dart';

import '../data/bookmark_store.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/bookmark.dart';
import '../models/reading_settings.dart';
import '../utils/scroll_ui_visibility.dart';
import '../utils/text_chunker.dart';
import '../utils/tts_reader.dart';
import '../widgets/glass.dart';
import '../widgets/reading_settings_sheet.dart';
import 'saved_items_screen.dart';

const _uuid = Uuid();

/// Read-only rendered view of a user-authored note (BookFormat.note) --
/// opened when tapping the note in the library, same as any other book.
/// Editing only happens through the library item's "..." menu ("수정"),
/// which opens NoteEditorScreen separately; this screen has no edit entry
/// point of its own.
///
/// Carries the same reading toolbar as the plain-text viewer (TTS, bookmark,
/// reading settings, search) so a note reads the same as any imported book
/// -- highlighting is the one thing deliberately left out, since it's
/// anchored by character offsets into rendered plain text, which don't
/// map cleanly back onto raw Markdown once formatting (`**bold**`, etc.)
/// is involved.
class NoteViewerScreen extends StatefulWidget {
  final String bookId;
  final String title;
  final String content;

  const NoteViewerScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.content,
  });

  @override
  State<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  final _scrollController = ScrollController();
  final _progressNotifier = ValueNotifier<double>(0);
  late final List<String> _chunks = splitIntoChunks(widget.content);

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
  List<int> _searchMatchChunks = [];
  int _currentMatchIndex = -1;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final position = _scrollController.position;
    _progressNotifier.value = position.maxScrollExtent <= 0
        ? 1
        : (position.pixels / position.maxScrollExtent).clamp(0, 1);
    final last = _lastScrollPixels;
    if (last != null && !_searchActive) {
      _uiVisibility.feed(position.pixels - last);
    }
    _lastScrollPixels = position.pixels;
  }

  @override
  void dispose() {
    if (_isSpeaking) TtsReader.instance.stop();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  void _seekToRatio(double ratio, {double topMargin = 0}) {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final target = ratio.clamp(0.0, 1.0) * maxExtent - topMargin;
    _scrollController.jumpTo(target.clamp(0.0, maxExtent));
  }

  // --- Text-to-speech ------------------------------------------------

  void _toggleSpeech() {
    if (_isSpeaking) {
      TtsReader.instance.stop();
      setState(() {
        _isSpeaking = false;
        _speakingChunkIndex = null;
      });
      return;
    }
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
    if (_chunks[index].trim().isEmpty) {
      _speakChunk(index + 1);
      return;
    }
    if (_chunks.length > 1) {
      // Landing the spoken paragraph flush at the very top edge puts it
      // right under the floating glass app bar; leave a quarter of the
      // viewport as headroom so it's actually visible.
      final viewport = _scrollController.hasClients
          ? _scrollController.position.viewportDimension
          : 0.0;
      _seekToRatio(index / (_chunks.length - 1), topMargin: viewport * 0.25);
    }
    setState(() {
      _isSpeaking = true;
      _speakingChunkIndex = index;
    });
    final settings = ReadingSettingsController.instance.value;
    TtsReader.instance.speak(
      _chunks[index],
      rate: settings.ttsRate,
      voice: TtsReader.instance.findVoice(settings.ttsVoiceUri),
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

  // --- Bookmarks -------------------------------------------------------

  String _previewNear(int chunkIndex) {
    for (var i = chunkIndex; i < _chunks.length; i++) {
      final text = _chunks[i].trim();
      if (text.isNotEmpty) {
        return text.length > 28 ? '${text.substring(0, 28)}…' : text;
      }
    }
    return tr('empty_paragraph');
  }

  Future<void> _addBookmark() async {
    if (!_scrollController.hasClients || _chunks.isEmpty) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final ratio = maxExtent > 0
        ? (_scrollController.offset / maxExtent).clamp(0.0, 1.0)
        : 0.0;
    final chunkIndex = (ratio * (_chunks.length - 1)).round().clamp(
      0,
      _chunks.length - 1,
    );
    final bookmark = Bookmark(
      id: _uuid.v4(),
      bookId: widget.bookId,
      position: _scrollController.offset,
      label: _previewNear(chunkIndex),
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
        builder: (_) =>
            SavedItemsScreen(bookId: widget.bookId, bookTitle: widget.title),
      ),
    );
    if (result == null || !mounted || !_scrollController.hasClients) return;
    final position = result.position;
    if (position is! num) return;
    _scrollController.animateTo(
      position.toDouble().clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // --- Search ------------------------------------------------------------

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      final q = query.trim();
      setState(() {
        _searchQuery = q;
        if (q.isEmpty) {
          _searchMatchChunks = [];
          _currentMatchIndex = -1;
          return;
        }
        final lowerQuery = q.toLowerCase();
        _searchMatchChunks = [
          for (var i = 0; i < _chunks.length; i++)
            if (_chunks[i].toLowerCase().contains(lowerQuery)) i,
        ];
        _currentMatchIndex = _searchMatchChunks.isEmpty ? -1 : 0;
      });
      if (_currentMatchIndex >= 0) _jumpToMatch(_currentMatchIndex);
    });
  }

  void _jumpToMatch(int matchIndex) {
    if (matchIndex < 0 || matchIndex >= _searchMatchChunks.length) return;
    final chunkIndex = _searchMatchChunks[matchIndex];
    if (_chunks.length > 1) _seekToRatio(chunkIndex / (_chunks.length - 1));
    setState(() => _currentMatchIndex = matchIndex);
  }

  void _nextMatch() {
    if (_searchMatchChunks.isEmpty) return;
    _jumpToMatch((_currentMatchIndex + 1) % _searchMatchChunks.length);
  }

  void _prevMatch() {
    if (_searchMatchChunks.isEmpty) return;
    _jumpToMatch(
      (_currentMatchIndex - 1 + _searchMatchChunks.length) %
          _searchMatchChunks.length,
    );
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchActive = false;
      _searchController.clear();
      _searchQuery = '';
      _searchMatchChunks = [];
      _currentMatchIndex = -1;
    });
  }

  // --- Styling -------------------------------------------------------

  MarkdownStyleSheet _styleSheetFor(ReadingSettings settings) {
    final base = settings.textStyle;
    final size = base.fontSize ?? 16;
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      h1: base.copyWith(fontSize: size * 1.8, fontWeight: FontWeight.w700),
      h2: base.copyWith(fontSize: size * 1.5, fontWeight: FontWeight.w700),
      h3: base.copyWith(fontSize: size * 1.3, fontWeight: FontWeight.w600),
      h4: base.copyWith(fontWeight: FontWeight.w600),
      h5: base.copyWith(fontWeight: FontWeight.w600),
      h6: base.copyWith(fontWeight: FontWeight.w600),
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      listBullet: base,
      blockquote: base.copyWith(color: base.color?.withValues(alpha: 0.7)),
      code: base.copyWith(
        fontFamily: 'monospace',
        fontSize: size * 0.9,
        backgroundColor: settings.background.textColor.withValues(
          alpha: 0.08,
        ),
      ),
      codeblockDecoration: BoxDecoration(
        color: settings.background.textColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      a: base.copyWith(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
    );
  }

  List<Widget> _buildAppBarActions(ReadingSettings settings) {
    final narrow = MediaQuery.of(context).size.width < 480;
    if (narrow) {
      return [
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'tts') _toggleSpeech();
            if (v == 'bookmark') _addBookmark();
            if (v == 'saved') _openSavedItems();
            if (v == 'settings') showReadingSettingsSheet(context);
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
          onPressed: () => setState(() {
            _searchActive = true;
            _uiVisible = true;
          }),
        ),
    ];
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
                                  _searchMatchChunks.isEmpty
                                      ? '0/0'
                                      : '${_currentMatchIndex + 1}/${_searchMatchChunks.length}',
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: tr('search_prev'),
                            icon: const Icon(Icons.keyboard_arrow_up),
                            onPressed: _searchMatchChunks.isEmpty
                                ? null
                                : _prevMatch,
                          ),
                          IconButton(
                            tooltip: tr('search_next'),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: _searchMatchChunks.isEmpty
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
                ? Center(child: Text(tr('empty_document')))
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(settings.pageMargin),
                    itemCount: _chunks.length,
                    itemBuilder: (context, index) {
                      final chunk = _chunks[index];
                      if (chunk.isEmpty) return const SizedBox(height: 16);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.only(bottom: 4),
                        color: index == _speakingChunkIndex
                            ? settings.background.textColor.withValues(
                                alpha: 0.08,
                              )
                            : (_searchQuery.isNotEmpty &&
                                  _searchMatchChunks.contains(index))
                            ? const Color(0x33FF9800)
                            : null,
                        child: MarkdownBody(
                          data: chunk,
                          styleSheet: _styleSheetFor(settings),
                          softLineBreak: true,
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
