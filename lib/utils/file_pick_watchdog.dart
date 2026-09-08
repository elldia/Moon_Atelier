import 'dart:async';
import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart' show FilePickerWebOptions;
import 'package:web/web.dart' as web;

/// Wraps [FilePicker.pickFile] with a recovery path for a specific iOS
/// Safari failure mode: `cancelUploadOnWindowBlur` is kept false (see the
/// call site) to avoid a real pick being falsely reported as cancelled, but
/// that also removes file_picker_web's only fallback for a pick that never
/// resolves at all -- e.g. a genuine cancel on a browser where the input's
/// 'cancel' event doesn't fire reliably, or (suspected, unconfirmed) the
/// page's JS getting suspended by iOS while the native picker sheet is up
/// and never cleanly resuming the pending 'change' handler.
///
/// This adds its own `window` focus listener (separate from, and with a far
/// more generous grace period than, file_picker_web's hardcoded 500ms one)
/// that starts a short countdown once the window regains focus — i.e. once
/// the native picker sheet has closed. If the pick still hasn't resolved by
/// then, treat it as cancelled (null) instead of leaving the caller waiting
/// on the outer, much longer safety-net timeout.
Future<PlatformFile?> pickFileWithWatchdog({
  required List<String> allowedExtensions,
  Duration graceAfterRefocus = const Duration(seconds: 6),
}) async {
  final pickFuture = FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    webOptions: const FilePickerWebOptions(cancelUploadOnWindowBlur: false),
  );

  final watchdog = Completer<PlatformFile?>();
  Timer? graceTimer;
  void onFocus(web.Event _) {
    graceTimer?.cancel();
    graceTimer = Timer(graceAfterRefocus, () {
      if (!watchdog.isCompleted) watchdog.complete(null);
    });
  }

  final jsOnFocus = onFocus.toJS;
  web.window.addEventListener('focus', jsOnFocus);
  try {
    return await Future.any([pickFuture, watchdog.future]);
  } finally {
    graceTimer?.cancel();
    web.window.removeEventListener('focus', jsOnFocus);
  }
}
