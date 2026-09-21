import 'package:flutter/material.dart';

import '../data/comic_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/comic_settings.dart';
import 'glass.dart';

/// Opens the comic-viewer preferences sheet (view mode, page-turn direction,
/// image quality). Unlike the e-book reading-settings dialog, changes apply
/// immediately — there's no draft/cancel step — since the effect (page
/// layout, filter quality) is safe to preview live behind the sheet.
Future<void> showComicSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GlassCard(
        opacity: 0.8,
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: ComicSettingsController.instance,
            builder: (context, _) {
              final settings = ComicSettingsController.instance.value;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
              );
            },
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
