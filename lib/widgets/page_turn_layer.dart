import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/comic_settings.dart';
import '../utils/text_line_geometry.dart';

/// Page-turn input for the e-book readers' [ReadingMode.page]: tapping an
/// edge zone (sized/placed like the comic viewer's, see
/// [ComicSettings.tapZoneFraction]) turns back/forward, the middle strip
/// toggles the reading UI, and a touch swipe, mouse wheel notch or arrow /
/// Page Up / Page Down / space key turns a page too.
///
/// Pages break on real line boundaries, measured from the laid-out text
/// (see [textLineAt]) rather than assumed from the font size — paragraph
/// gaps, headings and margins otherwise make a fixed step drift, so lines
/// end up half cut at the edges or repeated/skipped across a turn:
/// - a page ends just above the first line the bottom edge cuts through,
///   and a background-colored mask hides that partial line; turning
///   forward starts the next page exactly on it;
/// - turning back lands on the line boundary about a screen up and ends
///   that page exactly where the previous one began (except on reaching
///   the start of the book, which shows the usual full first page);
/// - landing anywhere else (opening the book, the progress slider, a
///   settings change) nudges a line cut by the top edge fully into view.
///
/// Taps are read from raw pointer events rather than a [GestureDetector]:
/// the text reader's [SelectableText] paragraphs claim taps in the gesture
/// arena first, so a tap recognizer up here would never fire over text.
/// Reading raw events also leaves long-press text selection untouched —
/// anything held longer than a tap is ignored.
class PageTurnLayer extends StatefulWidget {
  final ComicDirection direction;
  final double fraction;

  /// Scrolls the reading view by this many pixels (positive = forward).
  final ValueChanged<double> scrollBy;
  final VoidCallback onToggleUi;

  /// The reading background, used to mask a line cut off by the bottom
  /// edge (it's shown whole at the top of the next page instead).
  final Color maskColor;

  /// Checked on each tap; returning true ignores it — e.g. while a text
  /// selection is open, so tapping to dismiss it doesn't also turn the page.
  final bool Function()? ignoreTap;

  /// The scrolling reading view.
  final Widget child;

  const PageTurnLayer({
    super.key,
    required this.direction,
    required this.fraction,
    required this.scrollBy,
    required this.onToggleUi,
    required this.maskColor,
    this.ignoreTap,
    required this.child,
  });

  @override
  State<PageTurnLayer> createState() => _PageTurnLayerState();
}

class _PageTurnLayerState extends State<PageTurnLayer> {
  static const _maxTapDuration = Duration(milliseconds: 500);
  static const _maxSwipeDuration = Duration(milliseconds: 700);
  static const _minSwipeDistance = 60.0;

  final _contentKey = GlobalKey();

  int? _pointer;
  Offset _downPosition = Offset.zero;
  Duration _downTime = Duration.zero;
  PointerDeviceKind _downKind = PointerDeviceKind.touch;
  bool _multiTouch = false;
  DateTime? _lastWheelTurn;

  /// The view's latest scroll offset and its smallest possible one (the
  /// start of the book), from its scroll notifications.
  double? _pixels;
  double? _minPixels;

  /// Where (as a scroll offset) the current page has to end after turning
  /// back: exactly where the page turned back from began.
  double? _endPixels;

  bool _scrolling = false;
  double? _lastSnapPixels;

  /// Layer-local y from which the mask covers the bottom; infinite = none.
  double _maskTop = double.infinity;

  @override
  void initState() {
    super.initState();
    _scheduleLayoutCheck();
  }

  @override
  void didUpdateWidget(PageTurnLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleLayoutCheck();
  }

  RenderBox? get _contentBox {
    final box = _contentKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize && box.attached ? box : null;
  }

  /// Layer-local y where the current page's last whole line ends.
  double _pageEnd(RenderBox box, Rect viewport) {
    final end = _endPixels, pixels = _pixels, min = _minPixels;
    // Turning back onto the very start of the book shows the same full
    // first page as opening it, rather than a short page cut off where
    // the later page began.
    final atStart = pixels != null && min != null && pixels <= min + 0.5;
    if (end != null && pixels != null && !atStart) {
      final local = end - pixels;
      if (local > 0.5 && local <= viewport.height + 0.5) return local;
    }
    final cut = textLineAt(box, viewport.bottom - 0.5);
    if (cut != null &&
        cut.top > viewport.top + 0.5 &&
        cut.bottom > viewport.bottom + 0.5) {
      return cut.top - viewport.top;
    }
    return viewport.height;
  }

  void _turn(int direction) {
    final box = _contentBox;
    if (box == null) return;
    final viewport = box.localToGlobal(Offset.zero) & box.size;
    if (direction > 0) {
      var step = _pageEnd(box, viewport);
      if (step < 1) step = viewport.height;
      _endPixels = null;
      widget.scrollBy(step);
      return;
    }
    // Start the previous page on the first line boundary at or below one
    // screen up, so its top line isn't cut; it then ends exactly where the
    // current page begins (see _pageEnd).
    var top = viewport.top - viewport.height;
    final cut = textLineAt(box, top + 0.5);
    if (cut != null && cut.top < top - 0.5) top = cut.bottom;
    if (top >= viewport.top - 0.5) top = viewport.top - viewport.height;
    _endPixels = _pixels;
    widget.scrollBy(top - viewport.top);
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    _pixels = n.metrics.pixels;
    _minPixels = n.metrics.minScrollExtent;
    if (n is ScrollStartNotification) {
      _scrolling = true;
      _setMaskTop(double.infinity);
    } else if (n is ScrollEndNotification) {
      _scrolling = false;
      _scheduleLayoutCheck();
    }
    return false;
  }

  bool _onMetricsNotification(ScrollMetricsNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    _pixels = n.metrics.pixels;
    _minPixels = n.metrics.minScrollExtent;
    _scheduleLayoutCheck();
    return false;
  }

  void _scheduleLayoutCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLayout());
  }

  /// Runs after layout settles: nudges a line cut by the top edge into
  /// view, then masks the partial line at the bottom.
  void _checkLayout() {
    if (!mounted || _scrolling) return;
    final box = _contentBox;
    if (box == null) return;
    final viewport = box.localToGlobal(Offset.zero) & box.size;
    final top = textLineAt(box, viewport.top + 0.5);
    if (top != null &&
        top.top < viewport.top - 0.5 &&
        top.bottom - top.top < viewport.height &&
        _pixels != _lastSnapPixels) {
      _lastSnapPixels = _pixels;
      widget.scrollBy(top.top - viewport.top);
      return; // the scroll's end notification checks again
    }
    _setMaskTop(_pageEnd(box, viewport));
  }

  void _setMaskTop(double value) {
    if ((value - _maskTop).abs() < 0.5 ||
        (value.isInfinite && _maskTop.isInfinite)) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setMaskTop(value));
      return;
    }
    if (mounted) setState(() => _maskTop = value);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) {
      _multiTouch = true; // a pinch or two-finger gesture, not a tap
      return;
    }
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    _pointer = event.pointer;
    _downPosition = event.localPosition;
    _downTime = event.timeStamp;
    _downKind = event.kind;
    _multiTouch = false;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_multiTouch) return;
    final delta = event.localPosition - _downPosition;
    final elapsed = event.timeStamp - _downTime;
    if (delta.distance < kTouchSlop && elapsed < _maxTapDuration) {
      _handleTap(event.localPosition);
      return;
    }
    // Swipes are touch-only: a mouse drag is how desktop users select text.
    if (_downKind == PointerDeviceKind.mouse || elapsed > _maxSwipeDuration) {
      return;
    }
    final dx = delta.dx, dy = delta.dy;
    if (dx.abs() > _minSwipeDistance && dx.abs() > dy.abs() * 1.5) {
      _turn(dx < 0 ? 1 : -1);
    } else if (dy.abs() > _minSwipeDistance && dy.abs() > dx.abs() * 1.5) {
      _turn(dy < 0 ? 1 : -1);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _pointer = null;
  }

  void _handleTap(Offset position) {
    if (widget.ignoreTap?.call() ?? false) return;
    final size = _contentBox?.size ?? Size.zero;
    final horizontal = widget.direction == ComicDirection.horizontal;
    final extent = horizontal ? size.width : size.height;
    if (extent <= 0) return;
    final offset = horizontal ? position.dx : position.dy;
    if (offset < extent * widget.fraction) {
      _turn(-1);
    } else if (offset > extent * (1 - widget.fraction)) {
      _turn(1);
    } else {
      widget.onToggleUi();
    }
  }

  /// Debounced so one physical wheel notch — which can fire several scroll
  /// events in a browser — turns exactly one page (as in the comic viewer).
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta.abs() < 1) return;
    final now = DateTime.now();
    final last = _lastWheelTurn;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 180)) {
      return;
    }
    _lastWheelTurn = now;
    _turn(delta > 0 ? 1 : -1);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      _turn(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      _turn(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        onPointerSignal: _onPointerSignal,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: _onMetricsNotification,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: KeyedSubtree(key: _contentKey, child: widget.child),
              ),
            ),
            if (_maskTop.isFinite)
              Positioned(
                left: 0,
                right: 0,
                top: _maskTop,
                bottom: 0,
                child: IgnorePointer(
                  child: ColoredBox(color: widget.maskColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
