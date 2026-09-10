import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../utils/ftp_client.dart';
import 'glass.dart';

class FtpPickedFile {
  final String name;
  final Uint8List bytes;

  const FtpPickedFile({required this.name, required this.bytes});
}

/// Shows the FTP connect-and-browse dialog. Returns the downloaded file's
/// bytes once the user picks one, or null if they cancel.
Future<FtpPickedFile?> showFtpBrowserDialog(BuildContext context) {
  return showDialog<FtpPickedFile>(
    context: context,
    builder: (context) => const _FtpBrowserDialog(),
  );
}

class _FtpBrowserDialog extends StatefulWidget {
  const _FtpBrowserDialog();

  @override
  State<_FtpBrowserDialog> createState() => _FtpBrowserDialogState();
}

class _FtpBrowserDialogState extends State<_FtpBrowserDialog> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '21');
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  FtpSession? _session;
  List<FtpEntry> _entries = const [];
  String _currentPath = '/';
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_session?.disconnect());
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() => _error = tr('ftp_host_required'));
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final port = int.tryParse(_portController.text.trim()) ?? 21;
      final session = await FtpSession.connect(
        host: host,
        port: port,
        user: _userController.text.trim(),
        pass: _passController.text,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('FTP connect'),
      );
      final entries = await session.list();
      final path = await session.currentPath();
      if (!mounted) return;
      setState(() {
        _session = session;
        _entries = entries;
        _currentPath = path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr('ftp_connect_failed', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _refreshListing() async {
    final session = _session;
    if (session == null) return;
    final entries = await session.list();
    final path = await session.currentPath();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _currentPath = path;
    });
  }

  Future<void> _openFolder(String name) async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final ok = await session.changeDirectory(name);
      if (!ok) throw Exception(tr('ftp_open_folder_failed'));
      await _refreshListing();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr('ftp_action_failed', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _downloadFile(String name) async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final bytes = await session.downloadToBytes(name).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('FTP download'),
      );
      if (!mounted) return;
      Navigator.of(context).pop(FtpPickedFile(name: name, bytes: bytes));
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
    final connected = _session != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: GlassCard(
        opacity: 0.75,
        child: SizedBox(
          width: size.width < 480 ? size.width - 24 : 420,
          height: connected
              ? (size.height < 640 ? size.height - 48 : 520)
              : null,
          child: Column(
            mainAxisSize: connected ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('source_ftp'),
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
              Expanded(
                flex: connected ? 1 : 0,
                child: connected ? _buildBrowser() : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _hostController,
            enabled: !_isBusy,
            decoration: InputDecoration(labelText: tr('ftp_host')),
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            enabled: !_isBusy,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('ftp_port')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _userController,
            enabled: !_isBusy,
            decoration: InputDecoration(labelText: tr('ftp_user_optional')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passController,
            enabled: !_isBusy,
            obscureText: true,
            decoration: InputDecoration(
              labelText: tr('ftp_password_optional'),
            ),
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isBusy ? null : _connect,
            child: Text(tr('ftp_connect')),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowser() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: _isBusy || _currentPath == '/'
                    ? null
                    : () => _openFolder('..'),
              ),
              Expanded(
                child: Text(
                  _currentPath,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _entries.isEmpty
              ? Center(child: Text(tr('ftp_empty_folder')))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
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
                                ? _openFolder(entry.name)
                                : _downloadFile(entry.name),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
