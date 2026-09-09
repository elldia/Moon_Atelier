import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/strings.dart';
import '../widgets/glass.dart';

const _osmdCdnUrl =
    'https://cdn.jsdelivr.net/npm/opensheetmusicdisplay@1.8.6/build/opensheetmusicdisplay.min.js';

const _hostHtml =
    '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=4.0, user-scalable=yes">
  <script src="$_osmdCdnUrl"></script>
  <style>html,body,#score{margin:0;padding:0;width:100%;height:100%;background:#ffffff;}</style>
</head>
<body>
  <div id="score"></div>
  <script>
    function renderScore(xml) {
      try {
        var osmd = new opensheetmusicdisplay.OpenSheetMusicDisplay(
          document.getElementById('score'),
          {autoResize: true, backend: 'svg', drawTitle: true}
        );
        osmd.load(xml).then(function () {
          osmd.render();
          Status.postMessage('ok');
        }).catch(function (e) {
          Status.postMessage('error:' + e);
        });
      } catch (e) {
        Status.postMessage('error:' + e);
      }
    }
  </script>
</body>
</html>
''';

/// Native (Android/iOS/desktop) counterpart of the web build's
/// `music_score_viewer_screen_web.dart`: there's no Flutter-native package
/// with OpenSheetMusicDisplay's MusicXML rendering fidelity, so this embeds
/// a `webview_flutter` view and reuses the exact same JS library instead of
/// re-rendering scores through a different engine.
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
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'Status',
        onMessageReceived: (message) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = message.message.startsWith('error:')
                ? message.message.substring('error:'.length)
                : null;
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _controller.runJavaScript(
              'renderScore(${jsonEncode(widget.xml)})',
            );
          },
        ),
      )
      ..loadHtmlString(_hostHtml);
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
            // WebView is a native platform view -- it handles its own
            // pinch-zoom/pan (see the HTML's viewport meta tag) rather than
            // going through an InteractiveViewer, which can't win the
            // gesture arena against a platform view anyway.
            child: WebViewWidget(controller: _controller),
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
