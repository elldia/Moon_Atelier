import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Some EPUBs (commonly Calibre-converted Korean web-novel exports) ship a
/// `toc.ncx` with far fewer navPoints than the spine has reading-order
/// files — e.g. a single navPoint for the title page while 30+ real
/// chapter files sit in the spine with no NCX entry at all.
///
/// `epub_view` derives both its table of contents AND the actual rendered
/// book content from the NCX navMap rather than the spine, so any spine
/// file with no matching navPoint is silently never parsed or shown — the
/// reader just displays an empty title page forever.
///
/// This rewrites `toc.ncx` to have exactly one navPoint per spine item, in
/// spine (reading) order: an existing navPoint's label is reused wherever
/// its target already matches a spine file, and a label is synthesized
/// (from that chapter's own `<title>`, falling back to a numbered
/// placeholder) for the rest. If every spine file already has a matching
/// navPoint, the original bytes are returned unchanged.
Uint8List ensureFullEpubToc(Uint8List bytes) {
  try {
    return _ensureFullEpubToc(bytes);
  } catch (_) {
    // Best-effort normalization: any parsing surprise falls back to the
    // original bytes rather than breaking the book from opening at all.
    return bytes;
  }
}

Uint8List _ensureFullEpubToc(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  final containerFile = archive.findFile('META-INF/container.xml');
  if (containerFile == null) return bytes;
  final containerXml = XmlDocument.parse(
    utf8.decode(containerFile.content as List<int>),
  );
  final rootfiles = containerXml.findAllElements('rootfile');
  if (rootfiles.isEmpty) return bytes;
  final opfPath = rootfiles.first.getAttribute('full-path');
  if (opfPath == null) return bytes;

  final opfFile = archive.findFile(opfPath);
  if (opfFile == null) return bytes;
  final opfDir = opfPath.contains('/')
      ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
      : '';
  final opfXml = XmlDocument.parse(utf8.decode(opfFile.content as List<int>));

  final manifest =
      <String, String>{}; // manifest id -> href (relative to opfDir)
  for (final item in opfXml.findAllElements('item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id != null && href != null) manifest[id] = href;
  }

  final spineElements = opfXml.findAllElements('spine');
  if (spineElements.isEmpty) return bytes;
  final spine = spineElements.first;
  final spineHrefs = <String>[
    for (final itemref in spine.findElements('itemref'))
      if (manifest[itemref.getAttribute('idref')] != null)
        manifest[itemref.getAttribute('idref')]!,
  ];
  if (spineHrefs.isEmpty) return bytes;

  final tocId = spine.getAttribute('toc');
  final ncxHref = tocId == null ? null : manifest[tocId];
  if (ncxHref == null) return bytes;
  final ncxPath = '$opfDir$ncxHref';
  final ncxFile = archive.findFile(ncxPath);
  if (ncxFile == null) return bytes;

  final ncxXml = XmlDocument.parse(utf8.decode(ncxFile.content as List<int>));
  final navMaps = ncxXml.findAllElements('navMap');
  if (navMaps.isEmpty) return bytes;
  final navMap = navMaps.first;

  // file-part of an existing navPoint's content src -> its label text.
  final existingLabels = <String, String>{};
  for (final navPoint in ncxXml.findAllElements('navPoint')) {
    final contentEls = navPoint.findElements('content');
    if (contentEls.isEmpty) continue;
    final src = contentEls.first.getAttribute('src');
    if (src == null) continue;
    final labelEls = navPoint.findElements('navLabel');
    if (labelEls.isEmpty) continue;
    final textEls = labelEls.first.findElements('text');
    if (textEls.isEmpty) continue;
    final label = textEls.first.innerText.trim();
    if (label.isEmpty) continue;
    existingLabels.putIfAbsent(src.split('#').first, () => label);
  }

  final alreadyComplete = spineHrefs.every(existingLabels.containsKey);
  if (alreadyComplete) return bytes;

  // Each spine file's own <title>, for the hrefs that need a synthesized
  // label (no existing navPoint already covers them).
  final docTitles = <String, String>{};
  for (final href in spineHrefs) {
    if (existingLabels.containsKey(href)) continue;
    final chapterFile = archive.findFile('$opfDir$href');
    if (chapterFile == null) continue;
    try {
      final doc = XmlDocument.parse(
        utf8.decode(chapterFile.content as List<int>),
      );
      final titles = doc.findAllElements('title');
      final title = titles.isEmpty ? '' : titles.first.innerText.trim();
      if (title.isNotEmpty) docTitles[href] = title;
    } catch (_) {
      // Leave unset; titleFor() falls back to a numbered placeholder.
    }
  }
  // Some converters (notably Calibre auto-splits) stamp every chapter with
  // the same generic <title>, which would make a confusing TOC of
  // duplicate entries. Only trust <title> as a label when it actually
  // varies from chapter to chapter.
  final titlesAreDistinct = docTitles.values.toSet().length == docTitles.length;

  var syntheticCounter = 0;
  String titleFor(String href) {
    final existing = existingLabels[href];
    if (existing != null) return existing;
    syntheticCounter++;
    final docTitle = docTitles[href];
    if (docTitle != null && titlesAreDistinct) return docTitle;
    return '$syntheticCounter';
  }

  final newNavPoints = <XmlElement>[];
  for (var i = 0; i < spineHrefs.length; i++) {
    final href = spineHrefs[i];
    final fragmentBuilder = XmlBuilder();
    fragmentBuilder.element(
      'navPoint',
      attributes: {'id': 'patched_$i', 'playOrder': '${i + 1}'},
      nest: () {
        fragmentBuilder.element(
          'navLabel',
          nest: () {
            fragmentBuilder.element('text', nest: titleFor(href));
          },
        );
        fragmentBuilder.element('content', attributes: {'src': href});
      },
    );
    final built = fragmentBuilder.buildFragment().firstChild;
    if (built is XmlElement) newNavPoints.add(built.copy());
  }

  navMap.children.clear();
  navMap.children.addAll(newNavPoints);

  final patchedNcxBytes = utf8.encode(ncxXml.toXmlString());
  final newArchive = Archive();
  for (final file in archive.files) {
    newArchive.addFile(file);
  }
  newArchive.addFile(
    ArchiveFile(ncxPath, patchedNcxBytes.length, patchedNcxBytes),
  );

  final encoded = ZipEncoder().encode(newArchive);
  if (encoded == null) return bytes;
  return Uint8List.fromList(encoded);
}
