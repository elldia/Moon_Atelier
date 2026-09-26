import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';

import '../l10n/strings.dart';

/// Native-only: binds a real `dart:io` [HttpServer], which has no web
/// equivalent — see `wifi_transfer_server_web.dart` for the stub used there.
const bool isWifiTransferAvailable = true;

class WifiTransferPickedFile {
  final String name;
  final Uint8List bytes;

  const WifiTransferPickedFile({required this.name, required this.bytes});
}

/// A short-lived local HTTP server that shows a drag-and-drop upload page
/// and emits each uploaded file on [received] for as long as it's running,
/// so several files can be sent in one session. The address is just
/// `ip:port` -- no path -- so it's short enough to type by hand; the
/// tradeoff is that anyone else on the same LAN who guesses the port during
/// the brief window this is open could also reach the upload form (there's
/// no other secret in the URL to stop them).
class WifiTransferServer {
  HttpServer? _server;
  final _received = StreamController<WifiTransferPickedFile>();

  /// Every file uploaded while the server is up, in arrival order. Closes
  /// when [stop] is called.
  Stream<WifiTransferPickedFile> get received => _received.stream;

  /// Starts the server and returns the URL to open on the sending device,
  /// or null if no local network address could be found (e.g. no Wi-Fi).
  Future<String?> start() async {
    final ip = await _localIPv4();
    if (ip == null) return null;
    final handler = const Pipeline().addHandler(_handleRequest);
    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _server = server;
    return 'http://$ip:${server.port}';
  }

  Future<Response> _handleRequest(Request request) async {
    final segments = request.url.pathSegments;
    if (request.method == 'GET' && segments.isEmpty) {
      return Response.ok(
        _uploadPageHtml(),
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }
    if (request.method == 'POST' &&
        segments.length == 1 &&
        segments.first == 'upload') {
      final form = request.formData();
      if (form == null) {
        return Response(400, body: 'Not a multipart form');
      }
      var count = 0;
      await for (final field in form.formData) {
        final filename = field.filename;
        if (filename == null || filename.isEmpty) continue;
        final bytes = await field.part.readBytes();
        if (_received.isClosed) return Response(503, body: 'Closed');
        _received.add(WifiTransferPickedFile(name: filename, bytes: bytes));
        count++;
      }
      if (count == 0) return Response(400, body: 'No file field found');
      // The page's script only looks at the status code; this body is for
      // the no-JavaScript fallback, where the form posts here directly.
      return Response.ok(
        _successPageHtml(),
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }
    return Response.notFound('Not found');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    if (!_received.isClosed) await _received.close();
  }
}

Future<String?> _localIPv4() async {
  try {
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    )) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {
    // Falls through to null below.
  }
  return null;
}

String _h(String key) => const HtmlEscape().convert(tr(key));

const _pageStyle = '''
:root {
  --bg: #f4f5f9; --card: #ffffff; --text: #1d1f27; --muted: #6b7080;
  --line: #e3e5ee; --accent: #4f6bed; --accent-soft: rgba(79, 107, 237, 0.08);
  --ok: #1f9d63; --err: #d64545; --track: #eceef4;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #14161c; --card: #1d2029; --text: #eceef4; --muted: #9a9fb0;
    --line: #2d313d; --accent: #7d93ff; --accent-soft: rgba(125, 147, 255, 0.10);
    --ok: #43c68a; --err: #f07070; --track: #2a2e3a;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; min-height: 100vh; background: var(--bg); color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Apple SD Gothic Neo",
    "Malgun Gothic", "Noto Sans KR", sans-serif;
  display: flex; justify-content: center; padding: 48px 16px;
}
.card {
  width: 100%; max-width: 560px; background: var(--card); border-radius: 20px;
  padding: 28px; box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08); align-self: flex-start;
}
h1 { font-size: 22px; margin: 0 0 4px; }
.sub { color: var(--muted); font-size: 14px; margin: 0 0 22px; }
''';

String _uploadPageHtml() {
  final strings = jsonEncode({
    'waiting': tr('wifi_page_status_waiting'),
    'done': tr('wifi_page_status_done'),
    'failed': tr('wifi_page_status_failed'),
    'summary': tr('wifi_page_summary'),
  });
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_h('wifi_page_title')}</title>
<style>
$_pageStyle
.drop {
  display: flex; flex-direction: column; align-items: center; gap: 10px;
  border: 2px dashed var(--line); border-radius: 16px; padding: 44px 16px;
  text-align: center; cursor: pointer; transition: border-color .15s, background .15s;
}
.drop:hover, .drop.over { border-color: var(--accent); background: var(--accent-soft); }
.drop svg { width: 48px; height: 48px; color: var(--accent); }
.drop strong { font-size: 18px; }
.drop span { color: var(--muted); font-size: 14px; }
.drop input { display: none; }
.list-head {
  display: flex; justify-content: space-between; align-items: baseline;
  margin: 26px 0 10px; font-size: 14px;
}
.list-head b { font-size: 15px; }
.list-head span { color: var(--muted); }
ul { list-style: none; margin: 0; padding: 0; }
li { padding: 12px 0; border-top: 1px solid var(--line); }
.row { display: flex; align-items: center; gap: 12px; }
.icon {
  flex: none; width: 36px; height: 36px; border-radius: 10px; display: grid;
  place-items: center; background: var(--accent-soft); color: var(--accent);
  font-size: 11px; font-weight: 700; text-transform: uppercase;
}
.meta { flex: 1; min-width: 0; }
.name { font-size: 15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.size { color: var(--muted); font-size: 12px; margin-top: 2px; }
.state { flex: none; font-size: 13px; color: var(--muted); font-variant-numeric: tabular-nums; }
li.done .state { color: var(--ok); font-weight: 600; }
li.failed .state { color: var(--err); font-weight: 600; }
.bar { height: 4px; border-radius: 2px; background: var(--track); margin-top: 10px; overflow: hidden; }
.bar i { display: block; height: 100%; width: 0; background: var(--accent); transition: width .15s; }
li.done .bar, li.failed .bar { display: none; }
.empty { color: var(--muted); font-size: 14px; text-align: center; padding: 18px 0; border-top: 1px solid var(--line); }
.foot { color: var(--muted); font-size: 12px; text-align: center; margin-top: 22px; }
</style>
</head>
<body>
<main class="card">
  <h1>${_h('wifi_page_title')}</h1>
  <p class="sub">${_h('wifi_page_subtitle')}</p>
  <form method="POST" action="upload" enctype="multipart/form-data">
    <label class="drop" id="drop">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"
        stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M12 15V4m0 0L7.5 8.5M12 4l4.5 4.5"/>
        <path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>
      </svg>
      <strong>${_h('wifi_page_drop')}</strong>
      <span>${_h('wifi_page_or_click')}</span>
      <input type="file" name="file" id="picker" multiple>
    </label>
    <noscript><p style="text-align:center"><button type="submit">${_h('wifi_page_send')}</button></p></noscript>
  </form>
  <div class="list-head"><b>${_h('wifi_page_list')}</b><span id="summary"></span></div>
  <ul id="list"></ul>
  <div class="empty" id="empty">${_h('wifi_page_empty')}</div>
  <p class="foot">${_h('wifi_page_footer')}</p>
</main>
<script>
const T = $strings;
const drop = document.getElementById('drop');
const picker = document.getElementById('picker');
const list = document.getElementById('list');
const queue = [];
let busy = false, total = 0, done = 0;

function fmtSize(n) {
  if (n < 1024) return n + ' B';
  if (n < 1048576) return (n / 1024).toFixed(1) + ' KB';
  if (n < 1073741824) return (n / 1048576).toFixed(1) + ' MB';
  return (n / 1073741824).toFixed(2) + ' GB';
}
function updateSummary() {
  document.getElementById('empty').style.display = total ? 'none' : '';
  document.getElementById('summary').textContent = total
    ? T.summary.replace('{done}', done).replace('{total}', total) : '';
}
function add(files) {
  for (const file of files) {
    const li = document.createElement('li');
    const dot = file.name.lastIndexOf('.');
    li.innerHTML = '<div class="row"><div class="icon"></div><div class="meta">' +
      '<div class="name"></div><div class="size"></div></div><div class="state"></div></div>' +
      '<div class="bar"><i></i></div>';
    li.querySelector('.icon').textContent = dot > 0 ? file.name.slice(dot + 1, dot + 5) : 'FILE';
    li.querySelector('.name').textContent = file.name;
    li.querySelector('.size').textContent = fmtSize(file.size);
    li.querySelector('.state').textContent = T.waiting;
    list.appendChild(li);
    queue.push({ file, li });
    total++;
  }
  updateSummary();
  next();
}
function next() {
  if (busy || !queue.length) return;
  busy = true;
  const { file, li } = queue.shift();
  const state = li.querySelector('.state');
  const bar = li.querySelector('.bar i');
  const body = new FormData();
  body.append('file', file, file.name);
  const xhr = new XMLHttpRequest();
  xhr.open('POST', 'upload');
  xhr.upload.onprogress = (e) => {
    if (!e.lengthComputable) return;
    const pct = Math.round(e.loaded / e.total * 100);
    bar.style.width = pct + '%';
    state.textContent = pct + '%';
  };
  const finish = (ok) => {
    li.classList.add(ok ? 'done' : 'failed');
    state.textContent = ok ? '✓ ' + T.done : T.failed;
    if (ok) done++;
    updateSummary();
    busy = false;
    next();
  };
  xhr.onload = () => finish(xhr.status === 200);
  xhr.onerror = () => finish(false);
  xhr.send(body);
}

picker.addEventListener('change', () => { add(picker.files); picker.value = ''; });
['dragenter', 'dragover'].forEach((t) => window.addEventListener(t, (e) => {
  e.preventDefault();
  drop.classList.add('over');
}));
['dragleave', 'drop'].forEach((t) => window.addEventListener(t, (e) => {
  e.preventDefault();
  if (t === 'drop' || !e.relatedTarget) drop.classList.remove('over');
}));
window.addEventListener('drop', (e) => {
  if (e.dataTransfer && e.dataTransfer.files.length) add(e.dataTransfer.files);
});
updateSummary();
</script>
</body>
</html>
''';
}

String _successPageHtml() =>
    '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_h('wifi_page_sent')}</title>
<style>$_pageStyle</style>
</head>
<body>
<main class="card" style="text-align:center">
  <h1>${_h('wifi_page_sent')}</h1>
  <p class="sub">${_h('wifi_page_check_phone')}</p>
  <a href="./" style="color:var(--accent)">${_h('wifi_page_send_more')}</a>
</main>
</body>
</html>
''';
