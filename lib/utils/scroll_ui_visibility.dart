/// Tracks accumulated scroll delta to decide when a reader's chrome
/// (app bar / bottom bar) should hide or reappear: scrolling steadily
/// forward through the content (delta > 0, i.e. "down" in the normal
/// reading sense) past [threshold] hides it; scrolling back (delta < 0)
/// past [threshold] — or [show] being called directly, e.g. on a tap —
/// reveals it again. A small threshold with sign-reset-on-direction-change
/// avoids flickering on tiny jitters while still feeling responsive.
class ScrollUiVisibility {
  final void Function(bool visible) onChanged;
  final double threshold;
  bool visible = true;
  double _accum = 0;

  ScrollUiVisibility({required this.onChanged, this.threshold = 30});

  void feed(double delta) {
    if (delta == 0) return;
    if (delta.sign != _accum.sign) _accum = 0;
    _accum += delta;
    if (_accum > threshold && visible) {
      visible = false;
      _accum = 0;
      onChanged(false);
    } else if (_accum < -threshold && !visible) {
      visible = true;
      _accum = 0;
      onChanged(true);
    }
  }

  void show() {
    _accum = 0;
    if (!visible) {
      visible = true;
      onChanged(true);
    }
  }
}
