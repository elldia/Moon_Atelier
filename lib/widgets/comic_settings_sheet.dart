import 'package:flutter/material.dart';

import '../data/comic_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/comic_settings.dart';
import 'glass.dart';

/// Opens the comic-viewer preferences dialog (view mode, page-turn
/// direction, image quality), centered over the viewer at 80% of the
/// screen's width/height. Unlike the e-book reading-settings dialog,
/// changes apply immediately — there's no draft/cancel step — since the
/// effect (page layout, filter quality) is safe to preview live behind it.
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
              animation: ComicSettingsController.instance,
              builder: (context, _) {
                final settings = ComicSettingsController.instance.value;
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
                      // Continuous scroll is always vertical (see
                      // ComicViewerScreen._buildContinuousScroll), so this
                      // choice only means anything for single/two-page mode.
                      if (settings.viewMode !=
                          ComicViewMode.continuousScroll) ...[
                        const SizedBox(height: 16),
                        _SectionLabel(tr('comic_direction_section')),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final dir in ComicDirection.values)
                              ChoiceChip(
                                label: Text(tr('comic_dir_${dir.name}')),
                                selected: settings.direction == dir,
                                onSelected: (_) =>
                                    _set((s) => s.copyWith(direction: dir)),
                              ),
                          ],
                        ),
                      ],
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
                              label: Text(tr('comic_dir_${dir.name}')),
                              selected: settings.tapZoneDirection == dir,
                              onSelected: (_) => _set(
                                (s) => s.copyWith(tapZoneDirection: dir),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: settings.tapZoneFraction,
                              min: 0.25,
                              max: 0.5,
                              divisions: 5,
                              label:
                                  '${(settings.tapZoneFraction * 100).round()}%',
                              onChanged: (v) =>
                                  _set((s) => s.copyWith(tapZoneFraction: v)),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${(settings.tapZoneFraction * 100).round()}%',
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
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
