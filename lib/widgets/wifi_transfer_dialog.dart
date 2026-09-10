import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../utils/wifi_transfer_server.dart';
import 'glass.dart';

/// Starts a local upload server and shows its address until either a file
/// arrives (resolves with it) or the user cancels (resolves with null).
Future<WifiTransferPickedFile?> showWifiTransferDialog(BuildContext context) {
  return showDialog<WifiTransferPickedFile>(
    context: context,
    builder: (context) => const _WifiTransferDialog(),
  );
}

class _WifiTransferDialog extends StatefulWidget {
  const _WifiTransferDialog();

  @override
  State<_WifiTransferDialog> createState() => _WifiTransferDialogState();
}

class _WifiTransferDialogState extends State<_WifiTransferDialog> {
  final _server = WifiTransferServer();
  String? _address;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_startServer());
  }

  Future<void> _startServer() async {
    try {
      final address = await _server.start();
      if (!mounted) return;
      if (address == null) {
        setState(() => _error = tr('wifi_transfer_no_network'));
        return;
      }
      setState(() => _address = address);
      final file = await _server.waitForFile();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr('wifi_transfer_failed', {'error': '$e'}));
    }
  }

  @override
  void dispose() {
    unawaited(_server.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: GlassCard(
        opacity: 0.75,
        child: SizedBox(
          width: size.width < 480 ? size.width - 24 : 420,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('source_wifi'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                else if (_address == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Text(tr('wifi_transfer_instructions')),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: _address!));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('url_copied'))),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _address!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(Icons.copy, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(tr('wifi_transfer_waiting')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
