import 'package:flutter/material.dart';

import '../data/comic_settings_controller.dart';
import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/comic_settings.dart';
import '../models/reading_settings.dart';
import 'glass.dart';

/// Opens the comic-viewer preferences dialog (view mode, reading direction,
/// image quality, plus the app-wide language/display-mode and the comic
/// viewer's own background color), centered over the viewer at 80% of the
/// screen's width/height. Unlike the e-book reading-settings dialog,
/// changes apply immediately — there's no draft/cancel step — since every
/// effect here is safe to preview live behind it.
Future<void> showComicSettingsSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _ComicSettingsSheet(),
  );
}

class _ComicSettingsSheet extends StatelessWidget {
  const _ComicSettingsSheet();

  void _set(ComicSettings Function(ComicSettings current) updater) {
    ComicSettingsController.instance.update(updater);
  }

  void _setReading(ReadingSettings Function(ReadingSettings current) updater) {
    ReadingSettingsController.instance.update(updater);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: size.width * 0.8,
        height: size.height * 0.8,
        child: GlassCard(
          opacity: 0.8,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                ComicSettingsController.instance,
                ReadingSettingsController.instance,
              ]),
              builder: (context, _) {
                final settings = ComicSettingsController.instance.value;
                final readingSettings =
                    ReadingSettingsController.instance.value;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('comic_settings_title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('language_section')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final locale in AppLocale.values)
                            ChoiceChip(
                              label: Text(locale.label),
                              selected: readingSettings.locale == locale,
                              // ChoiceChip.onSelected fires even when
                              // re-tapping the chip that's already
                              // selected -- only reset the brand name when
                              // the locale is actually changing, or a
                              // manually-picked non-default brand name gets
                              // silently reset by tapping the current
                              // language again.
                              onSelected: (_) => _setReading(
                                (s) => s.locale == locale
                                    ? s
                                    : s.copyWith(
                                        locale: locale,
                                        appName: appBrandForLocale(locale),
                                      ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('display_mode')),
                      SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(tr('system_mode')),
                            icon: const Icon(Icons.brightness_auto),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(tr('light_mode')),
                            icon: const Icon(Icons.light_mode),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(tr('dark_mode')),
                            icon: const Icon(Icons.dark_mode),
                          ),
                        ],
                        selected: {readingSettings.themeMode},
                        onSelectionChanged: (v) =>
                            _setReading((s) => s.copyWith(themeMode: v.first)),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('background_color')),
                      _ComicBackgroundSelector(
                        value: settings.backgroundKey,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(backgroundKey: v)),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('comic_view_mode_section')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final mode in ComicViewMode.values)
                            ChoiceChip(
                              label: Text(tr('comic_view_${mode.name}')),
                              selected: settings.viewMode == mode,
                              onSelected: (_) =>
                                  _set((s) => s.copyWith(viewMode: mode)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('comic_reading_direction_section')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final dir in ComicReadingDirection.values)
                            ChoiceChip(
                              label: Text(tr('comic_reading_dir_${dir.name}')),
                              selected: settings.readingDirection == dir,
                              onSelected: (_) => _set(
                                (s) => s.copyWith(readingDirection: dir),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('comic_quality_section')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final q in ComicImageQuality.values)
                            ChoiceChip(
                              label: Text(tr('comic_quality_${q.name}')),
                              selected: settings.quality == q,
                              onSelected: (_) =>
                                  _set((s) => s.copyWith(quality: q)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('comic_tap_zone_section')),
                      Text(
                        tr('comic_tap_zone_desc'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final dir in ComicDirection.values)
                            ChoiceChip(
                              label: Text(tr('comic_tap_dir_${dir.name}')),
                              selected: settings.tapZoneDirection == dir,
                              onSelected: (_) => _set(
                                (s) => s.copyWith(tapZoneDirection: dir),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _TapZoneSizePicker(
                        direction: settings.tapZoneDirection,
                        value: settings.tapZoneFraction,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(tapZoneFraction: v)),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('comic_animate_section')),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('comic_animate_title')),
                        subtitle: Text(tr('comic_animate_desc')),
                        value: settings.animatePageTurns,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(animatePageTurns: v)),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('comic_progress_bar_section')),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('comic_progress_bar_title')),
                        subtitle: Text(tr('comic_progress_bar_desc')),
                        value: settings.showProgressBar,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(showProgressBar: v)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// A row of tap-zone size presets, each drawn as a small wireframe of the
/// screen with its edge zones shaded to scale — a picture of what tapping
/// will do, rather than a slider whose percentage number means nothing
/// until you've tried it.
class _TapZoneSizePicker extends StatelessWidget {
  final ComicDirection direction;
  final double value;
  final ValueChanged<double> onChanged;

  const _TapZoneSizePicker({
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

/// The comic viewer's own background swatch picker — visually identical to
/// the e-book reading dialog's, but a separate widget since that one's
/// `_BackgroundSwatch` is private to its own file.
class _ComicBackgroundSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ComicBackgroundSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final bg in ReadingBackground.presets)
          _ComicBackgroundSwatch(
            background: bg,
            selected: value == bg.key,
            onTap: () => onChanged(bg.key),
          ),
      ],
    );
  }
}

class _ComicBackgroundSwatch extends StatelessWidget {
  final ReadingBackground background;
  final bool selected;
  final VoidCallback onTap;
  const _ComicBackgroundSwatch({
    required this.background,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: selected ? 3 : 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            backgroundLabel(background.key),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
