import 'package:flutter/material.dart';

import '../models/comic_settings.dart';

/// A row of tap-zone size presets, each drawn as a small wireframe of the
/// screen with its edge zones shaded to scale — a picture of what tapping
/// will do, rather than a slider whose percentage number means nothing
/// until you've tried it. Shared by the comic viewer's and the e-book
/// reader's settings.
class TapZoneSizePicker extends StatelessWidget {
  final ComicDirection direction;
  final double value;
  final ValueChanged<double> onChanged;

  const TapZoneSizePicker({
    super.key,
    required this.direction,
    required this.value,
    required this.onChanged,
  });

  static const _presets = [0.2, 0.3, 0.4, 0.5];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        for (final fraction in _presets)
          _TapZoneThumbnail(
            fraction: fraction,
            horizontal: direction == ComicDirection.horizontal,
            selected: (value - fraction).abs() < 0.001,
            onTap: () => onChanged(fraction),
          ),
      ],
    );
  }
}

class _TapZoneThumbnail extends StatelessWidget {
  final double fraction;
  final bool horizontal;
  final bool selected;
  final VoidCallback onTap;

  const _TapZoneThumbnail({
    required this.fraction,
    required this.horizontal,
    required this.selected,
    required this.onTap,
  });

  static const _w = 52.0;
  static const _h = 68.0;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final bandColor = color.withValues(alpha: selected ? 0.55 : 0.25);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _w,
              height: _h,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? color : Theme.of(context).dividerColor,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  children: horizontal
                      ? [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: _w * fraction,
                            child: Container(color: bandColor),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: _w * fraction,
                            child: Container(color: bandColor),
                          ),
                        ]
                      : [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: _h * fraction,
                            child: Container(color: bandColor),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: _h * fraction,
                            child: Container(color: bandColor),
                          ),
                        ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(fraction * 100).round()}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? color : null,
                fontWeight: selected ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
