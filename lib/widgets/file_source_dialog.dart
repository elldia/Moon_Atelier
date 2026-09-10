import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'glass.dart';

/// Where the user wants to bring a new file in from. All of these are wired
/// up to a real picker.
enum FileSource { local, clipboard, dropbox, oneDrive, wifiTransfer, ftp }

/// Shows the "where do you want to add a file from" picker.
///
/// Every onPickX callback is invoked synchronously from inside the tapped
/// [ListTile]'s `onTap`, before the dialog is popped — not after awaiting
/// this function's returned Future, which always resolves once the dialog
/// closes (there's nothing left to report back). That ordering matters for
/// all but [onPickClipboard]: each of the others opens a native/third-party
/// picker (a `<input type="file">.click()`, Dropbox/OneDrive's own popup
/// windows, or this app's own FTP/Wi-Fi-transfer dialog) that browsers only
/// allow while still inside the same synchronous call stack as a real user
/// gesture ("transient activation"). Desktop browsers are lenient about a
/// short async gap, but mobile browsers (iOS Safari in particular) are not —
/// going through an awaited `Navigator.pop()` + dialog-close animation
/// first silently drops the picker, which looks like the button doing
/// nothing / spinning forever.
Future<void> showFileSourceDialog(
  BuildContext context, {
  required VoidCallback onPickLocal,
  required VoidCallback onPickClipboard,
  required VoidCallback onPickDropbox,
  required VoidCallback onPickOneDrive,
  required VoidCallback onPickFtp,
  required VoidCallback onPickWifiTransfer,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _FileSourceDialog(
      onPickLocal: onPickLocal,
      onPickClipboard: onPickClipboard,
      onPickDropbox: onPickDropbox,
      onPickOneDrive: onPickOneDrive,
      onPickFtp: onPickFtp,
      onPickWifiTransfer: onPickWifiTransfer,
    ),
  );
}

class _FileSourceDialog extends StatelessWidget {
  final VoidCallback onPickLocal;
  final VoidCallback onPickClipboard;
  final VoidCallback onPickDropbox;
  final VoidCallback onPickOneDrive;
  final VoidCallback onPickFtp;
  final VoidCallback onPickWifiTransfer;

  const _FileSourceDialog({
    required this.onPickLocal,
    required this.onPickClipboard,
    required this.onPickDropbox,
    required this.onPickOneDrive,
    required this.onPickFtp,
    required this.onPickWifiTransfer,
  });

  static const _options = [
    (FileSource.local, Icons.laptop_outlined, 'source_local', true),
    (
      FileSource.clipboard,
      Icons.content_paste_outlined,
      'source_clipboard',
      true,
    ),
    (FileSource.dropbox, Icons.cloud_queue_outlined, 'source_dropbox', true),
    (FileSource.oneDrive, Icons.cloud_outlined, 'source_onedrive', true),
    (FileSource.wifiTransfer, Icons.wifi_tethering, 'source_wifi', true),
    (FileSource.ftp, Icons.dns_outlined, 'source_ftp', true),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: GlassCard(
        opacity: 0.75,
        child: SizedBox(
          width: size.width < 480 ? size.width - 24 : 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('import_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  children: [
                    for (final (source, icon, labelKey, ready) in _options)
                      ListTile(
                        leading: Icon(icon),
                        title: Text(tr(labelKey)),
                        trailing: ready
                            ? null
                            : Text(
                                tr('coming_soon'),
                                style: const TextStyle(fontSize: 12),
                              ),
                        onTap: () {
                          switch (source) {
                            case FileSource.local:
                              // Fires FilePicker.pickFile() synchronously,
                              // before the pop, to preserve the tap's
                              // "transient activation" for mobile browsers.
                              onPickLocal();
                              Navigator.of(context).pop();
                              break;
                            case FileSource.clipboard:
                              onPickClipboard();
                              Navigator.of(context).pop();
                              break;
                            case FileSource.dropbox:
                              // Same transient-activation reasoning as
                              // local: Dropbox.choose() opens a real popup
                              // window, which browsers can block if it's
                              // not triggered synchronously from the tap.
                              onPickDropbox();
                              Navigator.of(context).pop();
                              break;
                            case FileSource.oneDrive:
                              // Same reasoning again: OneDrive.open() also
                              // opens a real popup window.
                              onPickOneDrive();
                              Navigator.of(context).pop();
                              break;
                            case FileSource.ftp:
                              // No transient-activation concern (it's our
                              // own Flutter dialog, not a browser popup),
                              // but pop after opening it for consistency.
                              onPickFtp();
                              Navigator.of(context).pop();
                              break;
                            case FileSource.wifiTransfer:
                              onPickWifiTransfer();
                              Navigator.of(context).pop();
                              break;
                          }
                        },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('cancel')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
