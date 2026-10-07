import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/book.dart';
import '../models/folder.dart';

/// Columns in the cover grid for a library [width]: three on phones, four
/// on tablets (and 7"-class e-readers), six on desktops.
int coverGridColumns(double width) {
  if (width < 600) return 3;
  if (width < 1024) return 4;
  return 6;
}

/// Comic covers are roughly 1 : 1.42 (B-series / tankōbon proportions).
const _coverAspect = 1.42;
const _spacing = 12.0;
const _padding = EdgeInsets.fromLTRB(12, 12, 12, 96);

/// The comic library as a responsive grid of cover thumbnails, folders
/// first. Covers come from [coverFor] (null while one is on its way, empty
/// when there is none) and are asked for through [requestCover] as their
/// tiles are built, so on-screen comics load first.
class ComicCoverGrid extends StatelessWidget {
  final List<Folder> folders;
  final List<Book> books;

  /// How many comics each folder holds, by folder id.
  final Map<String, int> folderCounts;

  final bool selectionMode;
  final Set<String> selectedFolderIds;
  final Set<String> selectedBookIds;

  final Uint8List? Function(String bookId) coverFor;
  final void Function(String bookId) requestCover;

  final void Function(Folder folder) onFolderTap;
  final void Function(Folder folder) onDeleteFolder;
  final void Function(Book book) onBookTap;

  /// A comic's menu entries and what picking one does — the same menu the
  /// name list shows.
  final List<PopupMenuEntry<String>> Function(Book book) bookMenu;
  final void Function(Book book, String action) onBookAction;

  const ComicCoverGrid({
    super.key,
    required this.folders,
    required this.books,
    required this.folderCounts,
    required this.selectionMode,
    required this.selectedFolderIds,
    required this.selectedBookIds,
    required this.coverFor,
    required this.requestCover,
    required this.onFolderTap,
    required this.onDeleteFolder,
    required this.onBookTap,
    required this.bookMenu,
    required this.onBookAction,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final titleStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontWeight: FontWeight.w500, height: 1.3);
    // Room under each cover for a two-line title at the current text size.
    final titleHeight =
        textScaler.scale((titleStyle?.fontSize ?? 12) * 1.3) * 2 + 8;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = coverGridColumns(constraints.maxWidth);
        final tileWidth =
            (constraints.maxWidth -
                _padding.horizontal -
                _spacing * (columns - 1)) /
            columns;
        final coverHeight = tileWidth * _coverAspect;
        final cacheWidth = (tileWidth * MediaQuery.devicePixelRatioOf(context))
            .round();
        return GridView.builder(
          padding: _padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing + 4,
            mainAxisExtent: coverHeight + titleHeight,
          ),
          itemCount: folders.length + books.length,
          itemBuilder: (context, index) {
            if (index < folders.length) {
              final folder = folders[index];
              return _Tile(
                coverHeight: coverHeight,
                title: folder.name,
                titleStyle: titleStyle,
                selectionMode: selectionMode,
                selected: selectedFolderIds.contains(folder.id),
                onTap: () => onFolderTap(folder),
                menu: [
                  PopupMenuItem(value: 'delete', child: Text(tr('delete'))),
                ],
                onMenu: (_) => onDeleteFolder(folder),
                cover: _FolderCover(count: folderCounts[folder.id] ?? 0),
              );
            }
            final book = books[index - folders.length];
            final cover = coverFor(book.id);
            if (cover == null) requestCover(book.id);
            return _Tile(
              coverHeight: coverHeight,
              title: book.name,
              titleStyle: titleStyle,
              selectionMode: selectionMode,
              selected: selectedBookIds.contains(book.id),
              onTap: () => onBookTap(book),
              menu: bookMenu(book),
              onMenu: (action) => onBookAction(book, action),
              progress: book.progress,
              cover: cover == null || cover.isEmpty
                  ? _PlaceholderCover(loading: cover == null)
                  : Image.memory(
                      cover,
                      key: ValueKey(book.id),
                      fit: BoxFit.cover,
                      cacheWidth: cacheWidth,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                    ),
            );
          },
        );
      },
    );
  }
}

/// One grid entry: a cover with the title under it, a menu button on the
/// cover's corner (long-press opens it too), a reading-progress strip
/// along its bottom, and a check mark in selection mode.
class _Tile extends StatelessWidget {
  final double coverHeight;
  final String title;
  final TextStyle? titleStyle;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final List<PopupMenuEntry<String>> menu;
  final void Function(String action) onMenu;
  final double? progress;
  final Widget cover;

  const _Tile({
    required this.coverHeight,
    required this.title,
    required this.titleStyle,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.menu,
    required this.onMenu,
    required this.cover,
    this.progress,
  });

  Future<void> _showMenuAt(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: menu,
    );
    if (action != null) onMenu(action);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = this.progress;
    return Semantics(
      button: true,
      selected: selectionMode ? selected : null,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: GestureDetector(
          onLongPressStart: selectionMode
              ? null
              : (details) => _showMenuAt(context, details.globalPosition),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: coverHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        cover,
                        if (progress != null && progress > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: Colors.black26,
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: selectionMode
                              ? Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: selected
                                      ? scheme.primary
                                      : Colors.white,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black54,
                                    ),
                                  ],
                                )
                              : _MenuButton(
                                  onPressed: (position) =>
                                      _showMenuAt(context, position),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  /// Still being made (vs. the comic has no cover image at all).
  final bool loading;
  const _PlaceholderCover({required this.loading});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.outline,
                ),
              )
            : Icon(Icons.auto_stories_outlined, color: scheme.outline),
      ),
    );
  }
}

class _FolderCover extends StatelessWidget {
  final int count;
  const _FolderCover({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 40, color: scheme.onSecondaryContainer),
          const SizedBox(height: 4),
          Text(
            tr('file_count', {'n': '$count'}),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// A small round ⋮ on the cover's corner — the standard menu button's 48px
/// minimum tap size would cover a good part of a phone-sized cover. Calls
/// [onPressed] with the point to open the menu at (its bottom-right).
class _MenuButton extends StatelessWidget {
  final void Function(Offset position) onPressed;
  const _MenuButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('more_options'),
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            final box = context.findRenderObject() as RenderBox;
            onPressed(box.localToGlobal(box.size.bottomRight(Offset.zero)));
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.more_vert, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
