import 'package:flutter/material.dart';

import '../data/bookmark_store.dart';
import '../data/highlight_store.dart';
import '../l10n/strings.dart';
import '../models/bookmark.dart';
import '../models/highlight.dart';
import '../widgets/glass.dart';

/// What the caller should scroll/jump to after the user taps a saved item.
/// [chunkIndex] is set for a highlight (text-based viewers only); otherwise
/// [position] carries the same per-format value as [Bookmark.position].
class SavedItemJump {
  final Object? position;
  final int? chunkIndex;
  const SavedItemJump({this.position, this.chunkIndex});
}

/// Lists this book's saved bookmarks and highlighted quotes. Tapping a row
/// pops a [SavedItemJump] so the caller can scroll to it.
class SavedItemsScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final bool showHighlights;

  const SavedItemsScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.showHighlights = true,
  });

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Bookmark> _bookmarks = [];
  List<Highlight> _highlights = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: widget.showHighlights ? 2 : 1, vsync: this);
    _reload();
  }

  void _reload() {
    setState(() {
      _bookmarks = BookmarkStore.forBook(widget.bookId);
      _highlights = widget.showHighlights
          ? HighlightStore.forBook(widget.bookId)
          : const [];
    });
  }

  Future<void> _deleteBookmark(Bookmark b) async {
    await BookmarkStore.delete(b.id);
    _reload();
  }

  Future<void> _deleteHighlight(Highlight h) async {
    await HighlightStore.delete(h.id);
    _reload();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bookmarkList = _bookmarks.isEmpty
        ? Center(child: Text(tr('no_bookmarks')))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            itemCount: _bookmarks.length,
            itemBuilder: (context, index) {
              final b = _bookmarks[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                onTap: () =>
                    Navigator.of(context)
                        .pop(SavedItemJump(position: b.position)),
                child: ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(
                    b.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_formatDate(b.createdAt)),
                  trailing: IconButton(
                    tooltip: tr('delete'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteBookmark(b),
                  ),
                ),
              );
            },
          );

    return Scaffold(
      appBar: glassAppBar(
        context,
        title: Text(widget.bookTitle, overflow: TextOverflow.ellipsis),
        bottom: widget.showHighlights
            ? TabBar(
                controller: _tab,
                tabs: [
                  Tab(
                    text: tr('bookmarks_count', {'n': '${_bookmarks.length}'}),
                  ),
                  Tab(text: tr('quotes_count', {'n': '${_highlights.length}'})),
                ],
              )
            : null,
      ),
      body: widget.showHighlights
          ? TabBarView(
              controller: _tab,
              children: [
                bookmarkList,
                _highlights.isEmpty
                    ? Center(child: Text(tr('no_quotes')))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: _highlights.length,
                        itemBuilder: (context, index) {
                          final h = _highlights[index];
                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            onTap: () => Navigator.of(context)
                                .pop(SavedItemJump(chunkIndex: h.chunkIndex)),
                            child: ListTile(
                              leading: Icon(
                                Icons.format_quote,
                                color: Color(0xFF000000 | h.color.toARGB32()),
                              ),
                              title: Text(
                                h.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(_formatDate(h.createdAt)),
                              trailing: IconButton(
                                tooltip: tr('delete'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteHighlight(h),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            )
          : bookmarkList,
    );
  }
}
