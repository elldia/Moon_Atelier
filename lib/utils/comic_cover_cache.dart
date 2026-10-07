import 'package:flutter/foundation.dart';

import '../data/cover_store.dart';
import '../data/library_store.dart';
import 'comic_cover.dart';

/// Hands the cover grid each comic's thumbnail, loading stored ones from
/// [CoverStore] and making missing ones from the archive. Requests are
/// worked through one at a time, in the order tiles ask (so what's on
/// screen comes first): making a cover means reading a whole archive —
/// often a hundred megabytes or more — and doing several at once would
/// hold several in memory together. Notifies listeners as each arrives.
class ComicCoverCache extends ChangeNotifier {
  final _covers = <String, Uint8List>{};
  final _queue = <String>[];
  final _queued = <String>{};
  bool _running = false;
  bool _disposed = false;

  /// The cover for [bookId]: PNG bytes, an empty list when the comic has
  /// none, or null while it's still on its way (see [request]).
  Uint8List? coverFor(String bookId) => _covers[bookId];

  /// Asks for [bookId]'s cover, if it isn't loaded or already queued.
  void request(String bookId) {
    if (_covers.containsKey(bookId) || !_queued.add(bookId)) return;
    _queue.add(bookId);
    _work();
  }

  /// Makes and stores the cover of a comic that was just added, from the
  /// [archiveBytes] already in hand, rather than reading them back.
  Future<void> createFrom(String bookId, Uint8List archiveBytes) async {
    final png = await buildComicCover(archiveBytes) ?? Uint8List(0);
    await CoverStore.save(bookId, png);
    _arrived(bookId, png);
  }

  /// Drops a deleted comic's cover.
  Future<void> forget(String bookId) async {
    _covers.remove(bookId);
    await CoverStore.delete(bookId);
  }

  Future<void> _work() async {
    if (_running) return;
    _running = true;
    while (_queue.isNotEmpty && !_disposed) {
      final id = _queue.removeAt(0);
      Uint8List png;
      try {
        png = await CoverStore.load(id) ?? await _make(id);
      } catch (_) {
        png = Uint8List(0);
      }
      _queued.remove(id);
      _arrived(id, png);
    }
    _running = false;
  }

  Future<Uint8List> _make(String bookId) async {
    final bytes = await LibraryStore.loadBytes(bookId);
    final png = bytes == null
        ? Uint8List(0)
        : await buildComicCover(bytes) ?? Uint8List(0);
    await CoverStore.save(bookId, png);
    return png;
  }

  void _arrived(String bookId, Uint8List png) {
    _covers[bookId] = png;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
