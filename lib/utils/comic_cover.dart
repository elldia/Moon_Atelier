import 'dart:typed_data';
import 'dart:ui' as ui;

import 'comic_archive.dart';

/// Cover thumbnails are decoded at this width — enough for the widest grid
/// tile (six columns on a desktop) on a high-density screen.
const comicCoverWidth = 360;

/// A PNG thumbnail of [archiveBytes]' first page (in reading order), or
/// null if the archive has no readable image. Uses the engine's own image
/// decoder, downscaling while decoding, so it works the same on every
/// platform and never holds the full-size page in memory.
Future<Uint8List?> buildComicCover(Uint8List archiveBytes) async {
  try {
    final archive = ComicArchive.fromBytes(archiveBytes);
    if (archive.pageCount == 0) return null;
    final codec = await ui.instantiateImageCodec(
      archive.pageBytes(0),
      targetWidth: comicCoverWidth,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
