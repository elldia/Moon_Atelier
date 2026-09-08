import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../l10n/strings.dart';
import '../widgets/glass.dart';

const _osmdCdnUrl =
    'https://cdn.jsdelivr.net/npm/opensheetmusicdisplay@1.8.6/build/opensheetmusicdisplay.min.js';

Completer<void>? _osmdLoadCompleter;

/// Injects the OpenSheetMusicDisplay UMD build once per page load (cached
/// via [_osmdLoadCompleter] so concurrent/repeat opens share one script tag).
Future<void> _ensureOsmdLoaded() {
  if (web.window.has('opensheetmusicdisplay')) {
    return Future.value();
  }
  final existing = _osmdLoadCompleter;
  if (existing != null) return existing.future;

  final completer = Completer<void>();
  _osmdLoadCompleter = completer;
  final script = web.HTMLScriptElement()
    ..src = _osmdCdnUrl
    ..type = 'application/javascript';
  script.addEventListener(
    'load',
    (web.Event _) {
      completer.complete();
    }.toJS,
  );
  script.addEventListener(
    'error',
    (web.Event _) {
      completer.completeError(
        StateError('Failed to load OpenSheetMusicDisplay from CDN'),
      );
    }.toJS,
  );
  web.document.head!.append(script);
  return completer.future;
}

var _viewIdCounter = 0;

/// Renders a MusicXML score (already extracted to raw XML text, whether the
/// source was an uncompressed .musicxml or a compressed .mxl) via
/// OpenSheetMusicDisplay, embedded as a web platform view.
class MusicScoreViewerScreen extends StatefulWidget {
  final String title;
  final String xml;

  const MusicScoreViewerScreen({
    super.key,
    required this.title,
    required this.xml,
  });

  @override
  State<MusicScoreViewerScreen> createState() =>
      _MusicScoreViewerScreenState();
}

class _MusicScoreViewerScreenState extends State<MusicScoreViewerScreen> {
  late final String _viewType;
  late final web.HTMLDivElement _hostDiv;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewType = 'music-score-view-${_viewIdCounter++}';
    _hostDiv = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.background = '#ffffff';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _hostDiv,
    );
    _load();
  }

  Future<void> _load() async {
    try {
      await _ensureOsmdLoaded();
      final module = web.window.getProperty<JSObject>(
        'opensheetmusicdisplay'.toJS,
      );
      final ctor = module.getProperty<JSFunction>(
        'OpenSheetMusicDisplay'.toJS,
      );
      final options = JSObject()
        ..setProperty('autoResize'.toJS, true.toJS)
        ..setProperty('backend'.toJS, 'svg'.toJS)
        ..setProperty('drawTitle'.toJS, true.toJS);
      final instance = ctor.callAsConstructor<JSObject>(_hostDiv, options);
      await instance
          .callMethod<JSPromise<JSAny?>>('load'.toJS, widget.xml.toJS)
          .toDart;
      instance.callMethod<JSAny?>('render'.toJS);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: glassAppBar(
        context,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: tr('back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: tr('home'),
            icon: const Icon(Icons.home_outlined),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: SizedBox.expand(
                child: HtmlElementView(viewType: _viewType),
              ),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('musicxml_open_error', {'error': _error!})),
              ),
            ),
        ],
      ),
    );
  }
}
