import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// The 처음으로/10 뒤로/10 앞으로/끝으로 icon row shown next to a reader's
/// seek bar for long content (100+ pages/chunks). Compact (36x36) tap
/// targets sized so all four fit comfortably in the ~30% width share this
/// gets alongside the seek bar, including on mobile.
class PageJumpRow extends StatelessWidget {
  final VoidCallback onFirst;
  final VoidCallback onBack10;
  final VoidCallback onForward10;
  final VoidCallback onLast;

  const PageJumpRow({
    super.key,
    required this.onFirst,
    required this.onBack10,
    required this.onForward10,
    required this.onLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _JumpIconButton(
          tooltip: tr('jump_first'),
          icon: Icons.first_page,
          onPressed: onFirst,
        ),
        _JumpIconButton(
          tooltip: tr('jump_back10'),
          icon: Icons.replay_10,
          onPressed: onBack10,
        ),
        _JumpIconButton(
          tooltip: tr('jump_forward10'),
          icon: Icons.forward_10,
          onPressed: onForward10,
        ),
        _JumpIconButton(
          tooltip: tr('jump_last'),
          icon: Icons.last_page,
          onPressed: onLast,
        ),
      ],
    );
  }
}

class _JumpIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _JumpIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
