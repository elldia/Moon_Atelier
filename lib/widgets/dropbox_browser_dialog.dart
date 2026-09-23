import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../utils/dropbox_picker_io.dart';
import 'glass.dart';

/// Shows the post-auth Dropbox folder browser -- [session] is already
/// signed in by the time this opens (see `chooseDropboxFile` in
/// dropbox_picker_io.dart). Returns the picked file's [DropboxFileResult],
/// or null if the user closes the dialog without picking one.
Future<DropboxFileResult?> showDropboxBrowserDialog(
  BuildContext context, {
  required DropboxSession session,
  List<String>? extensions,
}) {
  return showDialog<DropboxFileResult>(
    context: context,
    builder: (context) =>
        _DropboxBrowserDialog(session: session, extensions: extensions),
  );
}

class _DropboxBrowserDialog extends StatefulWidget {
  final DropboxSession session;
  final List<String>? extensions;

  const _DropboxBrowserDialog({required this.session, this.extensions});

  @override
  State<_DropboxBrowserDialog> createState() => _DropboxBrowserDialogState();
}

class _DropboxBrowserDialogState extends State<_DropboxBrowserDialog> {
  List<DropboxEntry> _entries = const [];
  // Dropbox's own root path is '' (not '/'); every non-root path it
  // returns already starts with '/' and never ends with one.
  String _currentPath = '';
  bool _isBusy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshListing());
  }

  bool _matchesFilter(DropboxEntry entry) {
    final exts = widget.extensions;
    if (exts == null || exts.isEmpty) return true;
    final lower = entry.name.toLowerCase();
    return exts.any((ext) => lower.endsWith(ext.toLowerCase()));
  }

  Future<void> _refreshListing() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final entries = await widget.session.list(_currentPath);
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr('ftp_action_failed', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openFolder(String path) async {
    setState(() => _currentPath = path);
    await _refreshListing();
  }

  Future<void> _openParent() async {
    final segments = _currentPath.split('/')..removeWhere((s) => s.isEmpty);
    segments.removeLast();
    await _openFolder(segments.isEmpty ? '' : '/${segments.join('/')}');
  }

  Future<void> _pickFile(DropboxEntry entry) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final link = await widget.session
          .temporaryLink(entry.pathLower)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Dropbox temporary link'),
          );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(DropboxFileResult(name: entry.name, link: link));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr('ftp_action_failed', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final visibleEntries = _entries
        .where((e) => e.isDirectory || _matchesFilter(e))
        .toList();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: GlassCard(
        opacity: 0.75,
        child: SizedBox(
          width: size.width < 480 ? size.width - 24 : 420,
          height: size.height < 640 ? size.height - 48 : 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('source_dropbox'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_isBusy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: _isBusy || _currentPath.isEmpty
                          ? null
                          : _openParent,
                    ),
                    Expanded(
                      child: Text(
                        _currentPath.isEmpty ? '/' : _currentPath,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleEntries.isEmpty && !_isBusy
                    ? Center(child: Text(tr('ftp_empty_folder')))
                    : ListView.builder(
                        itemCount: visibleEntries.length,
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          return ListTile(
                            leading: Icon(
                              entry.isDirectory
                                  ? Icons.folder_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(entry.name),
                            subtitle: !entry.isDirectory && entry.size != null
                                ? Text(_formatSize(entry.size!))
                                : null,
                            onTap: _isBusy
                                ? null
                                : () => entry.isDirectory
                                      ? _openFolder(entry.pathLower)
                                      : _pickFile(entry),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
