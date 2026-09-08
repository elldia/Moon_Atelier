import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../data/folder_store.dart';
import '../data/library_store.dart';
import '../models/book.dart';
import '../models/folder.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../utils/docx_text_extractor.dart';
import '../utils/epub_toc_patcher.dart';
import '../utils/musicxml_extractor.dart';
import '../utils/rtf_text_extractor.dart';
import '../widgets/coffee_dialog.dart';
import '../widgets/file_source_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/onboarding_dialog.dart';
import '../widgets/reading_settings_sheet.dart';
import 'epub_viewer_screen.dart';
import 'music_score_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'text_viewer_screen.dart';

const _uuid = Uuid();

enum BookSort {
  defaultOrder,
  recentlyRead,
  nameAsc,
  nameDesc,
  addedNewest,
  addedOldest,
}

String _sortLabel(BookSort s) => tr('sort_${s.name}');

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Book> _books = [];
  List<Folder> _folders = [];
  String? _currentFolderId;
  bool _isPicking = false;
  BookSort _sort = BookSort.defaultOrder;

  bool _searchActive = false;
  final _searchController = TextEditingController();
  String _query = '';

  bool _selectionMode = false;
  final Set<String> _selectedBookIds = {};
  final Set<String> _selectedFolderIds = {};

  // Temporary on-screen diagnostic for the mobile "add file" hang report —
  // shows exactly which step of the pick/read/save pipeline is in progress
  // or failed, since we have no console access on the reporter's device.
  final ValueNotifier<String> _debugStatus = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _books = LibraryStore.loadAll();
    _folders = FolderStore.loadAll();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maybeShowOnboarding(context),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debugStatus.dispose();
    super.dispose();
  }

  Folder? get _currentFolder {
    final id = _currentFolderId;
    if (id == null) return null;
    for (final f in _folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<void> _pickBook() async {
    setState(() => _isPicking = true);
    _debugStatus.value = '1) 파일 선택창 여는 중...';
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'epub',
          'pdf',
          'txt',
          'docx',
          'rtf',
          'musicxml',
          'mxl',
        ],
      );
      if (file == null) {
        _debugStatus.value = '(취소됨: 파일을 선택하지 않음)';
        return;
      }
      _debugStatus.value = '2) 선택됨: ${file.name} — 형식 확인 중...';

      final format = Book.formatFromExtension(file.extension);
      if (format == null) {
        if (!mounted) return;
        _debugStatus.value = '(실패: 지원하지 않는 형식)';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('unsupported_format'))));
        return;
      }

      _debugStatus.value = '3) 파일 내용 읽는 중...';
      final bytes = await file.readAsBytes().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('reading the picked file'),
      );
      _debugStatus.value = '4) ${bytes.length}바이트 읽음 — 저장소에 저장 중...';
      await _addBook(name: file.name, format: format, bytes: bytes, open: true);
      _debugStatus.value = '5) 저장 완료, 리더 화면으로 이동함';
    } catch (e) {
      if (!mounted) return;
      _debugStatus.value = '(실패: $e)';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('save_failed', {'error': '$e'}))));
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _addFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('clipboard_empty'))));
      return;
    }
    final name = tr('clipboard_text_name', {
      'ts': DateTime.now().toString().substring(0, 16),
    });
    await _addBook(
      name: name,
      format: BookFormat.txt,
      bytes: Uint8List.fromList(utf8.encode(text)),
      open: true,
    );
  }

  Future<void> _addBook({
    required String name,
    required BookFormat format,
    required Uint8List bytes,
    required bool open,
  }) async {
    final book = Book(
      id: _uuid.v4(),
      name: name,
      format: format,
      bytes: bytes,
      addedAt: DateTime.now(),
      folderId: _currentFolderId,
    );
    await LibraryStore.save(book);
    if (!mounted) return;
    setState(() => _books = [book, ..._books]);
    if (open) _openBook(book);
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('new_folder_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: tr('folder_name_hint')),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(tr('create')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final folder = Folder(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    await FolderStore.add(folder);
    if (!mounted) return;
    setState(
      () =>
          _folders = [..._folders, folder]
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_folder_confirm_title')),
        content: Text(tr('delete_folder_confirm_body', {'name': folder.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final affected = _books.where((b) => b.folderId == folder.id).toList();
    for (final b in affected) {
      await LibraryStore.save(b.copyWith(moveToRoot: true));
    }
    await FolderStore.delete(folder.id);
    if (!mounted) return;
    setState(() {
      _folders = _folders.where((f) => f.id != folder.id).toList();
      _books = [
        for (final b in _books)
          if (b.folderId == folder.id) b.copyWith(moveToRoot: true) else b,
      ];
      if (_currentFolderId == folder.id) _currentFolderId = null;
    });
  }

  Future<void> _moveBookToFolder(Book book) async {
    final chosen = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('move_to_folder')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: Row(
              children: [
                const Icon(Icons.folder_off_outlined),
                const SizedBox(width: 12),
                Text(tr('no_folder_root')),
              ],
            ),
          ),
          for (final folder in _folders)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(folder.id),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined),
                  const SizedBox(width: 12),
                  Text(folder.name),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    final updated = chosen.isEmpty
        ? book.copyWith(moveToRoot: true)
        : book.copyWith(folderId: chosen);
    await _updateBook(updated);
  }

  Future<void> _renameBook(Book book) async {
    final controller = TextEditingController(text: book.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('rename')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: tr('file_name_hint')),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(tr('rename')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == book.name) return;
    await _updateBook(book.copyWith(name: name));
  }

  Future<void> _showAddMenu() async {
    _debugStatus.value = '0) + 버튼 눌림';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassCard(
          opacity: 0.75,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: Text(tr('file_register')),
                  onTap: () => Navigator.of(context).pop('file'),
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text(tr('folder_create')),
                  onTap: () => Navigator.of(context).pop('folder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'file') {
      // onPickLocal/onPickClipboard fire synchronously from inside the
      // dialog's own onTap (see file_source_dialog.dart) rather than after
      // this awaited Future resolves, so the file chooser stays inside the
      // tap's transient activation on mobile browsers.
      _debugStatus.value = '0.5) 파일 등록 선택됨 — 소스 선택창 여는 중';
      final source = await showFileSourceDialog(
        context,
        onPickLocal: () {
          _debugStatus.value = '0.9) 내 컴퓨터에서 선택 눌림';
          unawaited(_pickBook());
        },
        onPickClipboard: () => unawaited(_addFromClipboard()),
      );
      if (!mounted || source == null) return;
      switch (source) {
        case FileSource.local:
        case FileSource.clipboard:
          break; // already handled synchronously via the callbacks above
        case FileSource.oneDrive:
        case FileSource.dropbox:
        case FileSource.cloudApp:
        case FileSource.wifiTransfer:
        case FileSource.ftp:
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(tr('import_not_ready'))));
          break;
      }
    } else if (action == 'folder') {
      await _createFolder();
    }
  }

  Future<void> _updateBook(Book updated) async {
    await LibraryStore.save(updated);
    if (!mounted) return;
    setState(() {
      _books = [
        for (final b in _books)
          if (b.id == updated.id) updated else b,
      ];
    });
  }

  Future<void> _deleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_book_confirm_title')),
        content: Text(tr('delete_book_confirm_body', {'name': book.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await LibraryStore.delete(book.id);
    if (!mounted) return;
    setState(() => _books = _books.where((b) => b.id != book.id).toList());
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedBookIds.clear();
      _selectedFolderIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final bookCount = _selectedBookIds.length;
    final folderCount = _selectedFolderIds.length;
    if (bookCount == 0 && folderCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_selected_confirm_title')),
        content: Text(
          [
                if (folderCount > 0)
                  tr('delete_selected_folders_part', {'n': '$folderCount'}),
                if (bookCount > 0)
                  tr('delete_selected_books_part', {'n': '$bookCount'}),
              ].join(', ') +
              tr('delete_selected_suffix'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final id in _selectedBookIds) {
      await LibraryStore.delete(id);
    }
    for (final id in _selectedFolderIds) {
      final affected = _books.where((b) => b.folderId == id).toList();
      for (final b in affected) {
        await LibraryStore.save(b.copyWith(moveToRoot: true));
      }
      await FolderStore.delete(id);
    }
    if (!mounted) return;
    setState(() {
      _books = [
        for (final b in _books)
          if (!_selectedBookIds.contains(b.id))
            if (_selectedFolderIds.contains(b.folderId))
              b.copyWith(moveToRoot: true)
            else
              b,
      ];
      _folders = _folders
          .where((f) => !_selectedFolderIds.contains(f.id))
          .toList();
      _selectionMode = false;
      _selectedBookIds.clear();
      _selectedFolderIds.clear();
    });
  }

  void _openBook(Book book) {
    final opened = book.copyWith(lastOpenedAt: DateTime.now());
    _updateBook(opened);

    // Position and progress arrive via separate debounced callbacks; track
    // the latest known state locally so neither update clobbers the other
    // (both build off `current`, not the original stale `opened` snapshot).
    var current = opened;

    switch (book.format) {
      case BookFormat.epub:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EpubViewerScreen(
              bookId: book.id,
              title: book.name,
              bytes: ensureFullEpubToc(book.bytes),
              initialCfi: book.position as String?,
              onPositionChanged: (cfi) {
                current = current.copyWith(position: cfi);
                _updateBook(current);
              },
              onProgressChanged: (p) {
                current = current.copyWith(progress: p);
                _updateBook(current);
              },
            ),
          ),
        );
        break;
      case BookFormat.pdf:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              bookId: book.id,
              title: book.name,
              bytes: book.bytes,
              initialPage: book.position as int?,
              onPositionChanged: (page) {
                current = current.copyWith(position: page);
                _updateBook(current);
              },
              onProgressChanged: (p) {
                current = current.copyWith(progress: p);
                _updateBook(current);
              },
            ),
          ),
        );
        break;
      case BookFormat.txt:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TextViewerScreen(
              bookId: book.id,
              title: book.name,
              content: utf8.decode(book.bytes, allowMalformed: true),
              initialOffset: (book.position as num?)?.toDouble(),
              onPositionChanged: (offset) {
                current = current.copyWith(position: offset);
                _updateBook(current);
              },
              onProgressChanged: (p) {
                current = current.copyWith(progress: p);
                _updateBook(current);
              },
            ),
          ),
        );
        break;
      case BookFormat.docx:
        _openExtractedText(
          book,
          opened,
          extract: extractDocxText,
          formatLabel: 'DOCX',
        );
        break;
      case BookFormat.rtf:
        _openExtractedText(
          book,
          opened,
          extract: extractRtfText,
          formatLabel: 'RTF',
        );
        break;
      case BookFormat.musicXml:
        try {
          final xml = extractMusicXmlText(book.bytes);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MusicScoreViewerScreen(title: book.name, xml: xml),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('open_error', {'format': 'MusicXML', 'error': '$e'}),
              ),
            ),
          );
        }
        break;
    }
  }

  void _openExtractedText(
    Book book,
    Book opened, {
    required String Function(Uint8List bytes) extract,
    required String formatLabel,
  }) {
    var current = opened;
    try {
      final text = extract(book.bytes);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TextViewerScreen(
            bookId: book.id,
            title: book.name,
            content: text,
            initialOffset: (book.position as num?)?.toDouble(),
            onPositionChanged: (offset) {
              current = current.copyWith(position: offset);
              _updateBook(current);
            },
            onProgressChanged: (p) {
              current = current.copyWith(progress: p);
              _updateBook(current);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('open_error', {'format': formatLabel, 'error': '$e'}),
          ),
        ),
      );
    }
  }

  IconData _iconFor(BookFormat format) {
    switch (format) {
      case BookFormat.epub:
        return Icons.menu_book;
      case BookFormat.pdf:
        return Icons.picture_as_pdf;
      case BookFormat.txt:
        return Icons.description;
      case BookFormat.docx:
        return Icons.article;
      case BookFormat.rtf:
        return Icons.article;
      case BookFormat.musicXml:
        return Icons.music_note;
    }
  }

  /// "1,234 / 45,678자 · 32%" for plain TXT (character counts are free —
  /// the raw bytes are already in memory), or just "32%" for every other
  /// format (an exact character count would mean re-parsing DOCX/RTF or
  /// isn't meaningful for EPUB/PDF). Null until the book has been opened
  /// at least once.
  String? _progressLabel(Book book) {
    final progress = book.progress;
    if (progress == null) return null;
    final percent = (progress * 100).round();
    if (book.format == BookFormat.txt) {
      final total = utf8.decode(book.bytes, allowMalformed: true).length;
      final current = (progress * total).round();
      return tr('char_progress', {
        'current': _formatCount(current),
        'total': _formatCount(total),
        'percent': '$percent',
      });
    }
    return '$percent%';
  }

  String _formatCount(int n) {
    final digits = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  List<Book> _sortBooks(List<Book> books) {
    final sorted = [...books];
    switch (_sort) {
      case BookSort.nameAsc:
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case BookSort.nameDesc:
        sorted.sort((a, b) => b.name.compareTo(a.name));
        break;
      case BookSort.addedNewest:
        sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case BookSort.addedOldest:
        sorted.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      case BookSort.recentlyRead:
        sorted.sort((a, b) {
          final at = a.lastOpenedAt;
          final bt = b.lastOpenedAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        break;
      case BookSort.defaultOrder:
        sorted.sort((a, b) {
          final at = a.lastOpenedAt ?? a.addedAt;
          final bt = b.lastOpenedAt ?? b.addedAt;
          return bt.compareTo(at);
        });
        break;
    }
    return sorted;
  }

  Future<void> _pickSort() async {
    final chosen = await showDialog<BookSort>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('sort')),
        children: [
          for (final s in BookSort.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(s),
              child: Row(
                children: [
                  Icon(
                    _sort == s
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(_sortLabel(s)),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    setState(() => _sort = chosen);
  }

  List<Widget> _buildActions(bool narrow) {
    if (_selectionMode) {
      return [
        IconButton(
          tooltip: tr('select_delete'),
          icon: const Icon(Icons.delete_outline),
          onPressed: _deleteSelected,
        ),
      ];
    }
    if (_searchActive) {
      return [
        IconButton(
          tooltip: tr('close_search'),
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _searchActive = false;
            _query = '';
            _searchController.clear();
          }),
        ),
      ];
    }
    if (narrow) {
      return [
        IconButton(
          tooltip: tr('search'),
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searchActive = true),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'sort') _pickSort();
            if (v == 'trash') _toggleSelectionMode();
            if (v == 'settings') showReadingSettingsSheet(context);
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'sort', child: Text(tr('sort'))),
            PopupMenuItem(value: 'trash', child: Text(tr('select_delete'))),
            PopupMenuItem(
              value: 'settings',
              child: Text(tr('reading_settings')),
            ),
          ],
        ),
      ];
    }
    return [
      IconButton(
        tooltip: tr('search'),
        icon: const Icon(Icons.search),
        onPressed: () => setState(() => _searchActive = true),
      ),
      IconButton(
        tooltip: tr('sort'),
        icon: const Icon(Icons.sort),
        onPressed: _pickSort,
      ),
      IconButton(
        tooltip: tr('select_delete'),
        icon: const Icon(Icons.delete_outline),
        onPressed: _toggleSelectionMode,
      ),
      IconButton(
        tooltip: tr('reading_settings'),
        icon: const Icon(Icons.tune),
        onPressed: () => showReadingSettingsSheet(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final folder = _currentFolder;
    final query = _query.trim().toLowerCase();

    var visibleFolders = folder == null ? _folders : const <Folder>[];
    var visibleBooks = _books
        .where((b) => b.folderId == _currentFolderId)
        .toList();
    if (query.isNotEmpty) {
      visibleFolders = visibleFolders
          .where((f) => f.name.toLowerCase().contains(query))
          .toList();
      visibleBooks = _books
          .where((b) => b.name.toLowerCase().contains(query))
          .toList();
    }
    visibleBooks = _sortBooks(visibleBooks);
    final isEmpty = visibleFolders.isEmpty && visibleBooks.isEmpty;

    final width = MediaQuery.of(context).size.width;
    final narrow = width < 480;

    return AnimatedBuilder(
      animation: ReadingSettingsController.instance,
      builder: (context, _) {
        final settings = ReadingSettingsController.instance.value;
        final appName = settings.appName;
        return Scaffold(
          appBar: glassAppBar(
            context,
            leading: _selectionMode
                ? IconButton(
                    tooltip: tr('cancel_selection'),
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSelectionMode,
                  )
                : folder == null
                ? null
                : IconButton(
                    tooltip: tr('back'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _currentFolderId = null),
                  ),
            title: _selectionMode
                ? Text(
                    tr('selected_count', {
                      'n':
                          '${_selectedBookIds.length + _selectedFolderIds.length}',
                    }),
                  )
                : _searchActive
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: tr('search_hint'),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  )
                : Text(
                    folder?.name ?? appName.label,
                    overflow: TextOverflow.ellipsis,
                  ),
            actions: _buildActions(narrow),
          ),
          body: isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_stories,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        query.isNotEmpty
                            ? tr('no_search_results')
                            : folder == null
                            ? tr('no_files_yet')
                            : tr('folder_empty'),
                      ),
                      const SizedBox(height: 8),
                      Text(tr('supported_formats_hint')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  itemCount: visibleFolders.length + visibleBooks.length,
                  itemBuilder: (context, index) {
                    if (index < visibleFolders.length) {
                      final f = visibleFolders[index];
                      final count = _books
                          .where((b) => b.folderId == f.id)
                          .length;
                      final selected = _selectedFolderIds.contains(f.id);
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        onTap: _selectionMode
                            ? () => setState(() {
                                if (selected) {
                                  _selectedFolderIds.remove(f.id);
                                } else {
                                  _selectedFolderIds.add(f.id);
                                }
                              })
                            : () => setState(() => _currentFolderId = f.id),
                        child: ListTile(
                          leading: _selectionMode
                              ? Checkbox(
                                  value: selected,
                                  onChanged: (_) => setState(() {
                                    if (selected) {
                                      _selectedFolderIds.remove(f.id);
                                    } else {
                                      _selectedFolderIds.add(f.id);
                                    }
                                  }),
                                )
                              : const Icon(Icons.folder),
                          title: Text(f.name, overflow: TextOverflow.ellipsis),
                          subtitle: Text(tr('file_count', {'n': '$count'})),
                          trailing: _selectionMode
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: tr('delete_folder'),
                                  onPressed: () => _deleteFolder(f),
                                ),
                        ),
                      );
                    }
                    final book = visibleBooks[index - visibleFolders.length];
                    final selected = _selectedBookIds.contains(book.id);
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      onTap: _selectionMode
                          ? () => setState(() {
                              if (selected) {
                                _selectedBookIds.remove(book.id);
                              } else {
                                _selectedBookIds.add(book.id);
                              }
                            })
                          : () => _openBook(book),
                      child: ListTile(
                        leading: _selectionMode
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) => setState(() {
                                  if (selected) {
                                    _selectedBookIds.remove(book.id);
                                  } else {
                                    _selectedBookIds.add(book.id);
                                  }
                                }),
                              )
                            : (settings.showFormatIcon
                                  ? Icon(_iconFor(book.format))
                                  : null),
                        title: Text(book.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            book.format.name.toUpperCase(),
                            if (_progressLabel(book) != null)
                              _progressLabel(book)!,
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: _selectionMode
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'rename') _renameBook(book);
                                  if (action == 'move') {
                                    _moveBookToFolder(book);
                                  }
                                  if (action == 'delete') _deleteBook(book);
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text(tr('rename')),
                                  ),
                                  PopupMenuItem(
                                    value: 'move',
                                    child: Text(tr('move_to_folder')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(tr('delete')),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
          floatingActionButton: _selectionMode
              ? null
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CoffeeButton(),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      tooltip: tr('add'),
                      onPressed: _isPicking ? null : _showAddMenu,
                      child: _isPicking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                    ),
                  ],
                ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ValueListenableBuilder<String>(
                valueListenable: _debugStatus,
                builder: (context, status, _) => Text(
                  status.isEmpty ? tr('large_file_delay_hint') : status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: status.isEmpty
                        ? Theme.of(context).hintColor
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: status.isEmpty ? null : FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
