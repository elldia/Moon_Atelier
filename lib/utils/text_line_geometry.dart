import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';

/// The global top/bottom of one laid-out line of text.
typedef TextLineSpan = ({double top, double bottom});

/// Finds the line of text drawn across global [y] anywhere under [root], or
/// null when [y] falls between lines (paragraph spacing, margins, images).
///
/// Lines come from each paragraph's own selection boxes, so headings,
/// paragraph gaps and mixed font sizes are all measured as actually laid
/// out rather than assumed from the font size. Plain [RenderParagraph]s are
/// measured with [BoxHeightStyle.max] (the full line box); a
/// [RenderEditable] (a SelectableText) uses its own `selectionHeightStyle`,
/// so its widget should set that to [BoxHeightStyle.max] as well.
TextLineSpan? textLineAt(RenderObject root, double y) {
  TextLineSpan? found;

  // Subtrees are skipped when their box doesn't span y — but only inside a
  // scrolling list's items: the list's own viewport (and everything around
  // it) is just the visible window, while the items laid out above/below
  // it (the cache extent) are exactly what a page turn needs to measure.
  void visit(RenderObject node, bool inList) {
    if (found != null) return;
    if (node is RenderBox) {
      if (!node.hasSize || !node.attached) return;
      final rect = MatrixUtils.transformRect(
        node.getTransformTo(null),
        Offset.zero & node.size,
      );
      final spansY = y >= rect.top && y < rect.bottom;
      if (inList && !spansY) return;
      if (spansY && node is RenderParagraph) {
        found = _lineIn(
          node,
          y,
          node.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: node.text.toPlainText().length,
            ),
            boxHeightStyle: BoxHeightStyle.max,
          ),
        );
        return;
      }
      if (spansY && node is RenderEditable) {
        final length = node.text?.toPlainText().length ?? 0;
        found = _lineIn(
          node,
          y,
          node.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: length),
          ),
        );
        return;
      }
    }
    final childInList = inList || node is RenderSliver;
    node.visitChildren((child) => visit(child, childInList));
  }

  visit(root, false);
  return found;
}

TextLineSpan? _lineIn(RenderBox box, double globalY, List<TextBox> boxes) {
  final localY = box.globalToLocal(Offset(0, globalY)).dy;
  for (final b in boxes) {
    // Inline widgets (e.g. a paragraph-indent SizedBox) show up as
    // near-zero-height placeholder boxes; they aren't lines.
    if (b.bottom - b.top < 1) continue;
    if (localY >= b.top && localY < b.bottom) {
      final top = box.localToGlobal(Offset(0, b.top)).dy;
      final bottom = box.localToGlobal(Offset(0, b.bottom)).dy;
      return (top: top, bottom: bottom);
    }
  }
  return null;
}
