import 'dart:typed_data';

import 'package:archive/archive.dart';

const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

bool _isImageEntry(ArchiveFile file) {
  if (!file.isFile) return false;
  final dot = file.name.lastIndexOf('.');
  if (dot < 0) return false;
  return _imageExtensions.contains(file.name.substring(dot + 1).toLowerCase());
}

/// Whether a .zip/.cbz archive contains at least one image file, i.e. looks
/// like a comic (a sequence of page images) rather than some other kind of
/// zip. Used to reject non-comic zips early with a clear error instead of
/// opening a blank/empty viewer.
bool looksLikeComicArchive(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes).files.any(_isImageEntry);
  } catch (_) {
    return false;
  }
}

/// A decoded comic archive: every image entry, sorted into natural reading
/// order. Page bytes are decompressed lazily (on first [pageBytes] call for
/// that index) since `archive` only reads the central directory up front.
class ComicArchive {
  final List<ArchiveFile> _pages;

  ComicArchive._(this._pages);

  factory ComicArchive.fromBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final pages = archive.files.where(_isImageEntry).toList()
      ..sort((a, b) => _naturalCompare(a.name, b.name));
    return ComicArchive._(pages);
  }

  int get pageCount => _pages.length;

  Uint8List pageBytes(int index) => _pages[index].content;
}

final _tokenPattern = RegExp(r'\d+|\D+');

/// Compares names digit-run by digit-run so "page2.jpg" sorts before
/// "page10.jpg" (a plain string compare would put "page10" first).
int _naturalCompare(String a, String b) {
  final aTokens = _tokenPattern.allMatches(a).map((m) => m.group(0)!).toList();
  final bTokens = _tokenPattern.allMatches(b).map((m) => m.group(0)!).toList();
  final len = aTokens.length < bTokens.length
      ? aTokens.length
      : bTokens.length;
  for (var i = 0; i < len; i++) {
    final aNum = int.tryParse(aTokens[i]);
    final bNum = int.tryParse(bTokens[i]);
    final cmp = (aNum != null && bNum != null)
        ? aNum.compareTo(bNum)
        : aTokens[i].compareTo(bTokens[i]);
    if (cmp != 0) return cmp;
  }
  return aTokens.length.compareTo(bTokens.length);
}
