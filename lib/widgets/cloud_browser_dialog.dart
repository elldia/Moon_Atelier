import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'glass.dart';

/// One entry (file or folder) in a cloud drive listing. [id] is whatever
/// the service addresses it by — a lowercase path for Dropbox, an item id
/// for OneDrive.
class CloudEntry {
  final String id;
  final String name;
  final bool isDirectory;
  final int? size;

  const CloudEntry({
    required this.id,
    required this.name,
    required this.isDirectory,
    this.size,
  });
}

/// A signed-in cloud drive the browser dialog can walk through.
abstract class CloudDriveSource {
  /// Shown as the dialog's title.
  String get title;

  /// Lists the folder [folderId] (null for the drive's root), folders
  /// first, each group alphabetical.
  Future<List<CloudEntry>> list(String? folderId);

  /// A short-lived URL that downloads [file] with a plain, unauthenticated
  /// GET — so the library's shared download step needs no session.
  Future<String> downloadUrl(CloudEntry file);
}

/// What the user picked: the file's name and a download URL for it.
typedef CloudPick = ({String name, String url});

/// Shows a folder browser over [source] (already signed in), listing
/// folders plus only the files ending in one of [extensions] (all files
/// when null/empty). Resolves with the picked file, or null if the dialog
/// is closed without picking one.
Future<CloudPick?> showCloudBrowserDialog(
  BuildContext context, {
  required CloudDriveSource source,
  List<String>? extensions,
}) {
  return showDialog<CloudPick>(
    context: context,
    builder: (context) =>
        _CloudBrowserDialog(source: source, extensions: extensions),
  );
}

class _CloudBrowserDialog extends StatefulWidget {
  final CloudDriveSource source;
  final List<String>? extensions;

  const _CloudBrowserDialog({required this.source, this.extensions});

  @override
  State<_CloudBrowserDialog> createState() => _CloudBrowserDialogState();
}

class _CloudBrowserDialogState extends State<_CloudBrowserDialog> {
  List<CloudEntry> _entries = const [];
  // The folders opened from the root, in order — the last is the one
  // shown. Kept as a stack (not a path to split) since OneDrive addresses
  // folders by id, not by path.
  final _trail = <CloudEntry>[];
  bool _isBusy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshListing());
  }

  bool _matchesFilter(CloudEntry entry) {
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
      final entries = await widget.source.list(
        _trail.isEmpty ? null : _trail.last.id,
      );
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr('ftp_action_failed', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openFolder(CloudEntry folder) async {
    setState(() => _trail.add(folder));
    await _refreshListing();
  }

  Future<void> _openParent() async {
    setState(() => _trail.removeLast());
    await _refreshListing();
  }

  Future<void> _pickFile(CloudEntry entry) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final url = await widget.source
          .downloadUrl(entry)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('cloud download link'),
          );
      if (!mounted) return;
      Navigator.of(context).pop((name: entry.name, url: url));
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
    final path = '/${_trail.map((f) => f.name).join('/')}';
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
                      widget.source.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      tooltip: tr('close'),
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
                      tooltip: tr('back'),
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: _isBusy || _trail.isEmpty
                          ? null
                          : _openParent,
                    ),
                    Expanded(
                      child: Text(
                        path,
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
                                      ? _openFolder(entry)
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
