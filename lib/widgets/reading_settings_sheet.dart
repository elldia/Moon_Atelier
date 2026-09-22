import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/reading_settings.dart';
import '../utils/backup_exporter.dart';
import '../utils/backup_importer.dart';
import '../utils/file_pick_watchdog.dart';
import '../utils/tts_reader.dart';
import 'glass.dart';

/// Opens the shared reading-preferences dialog. Safe to call from the
/// library screen or from any viewer while reading. Changes are staged
/// locally and only take effect (and persist) once '적용' is pressed —
/// '취소' or tapping outside discards them. [onLibraryRestored], if given,
/// fires right after a backup restore succeeds, so a caller showing a book
/// list (the library screen) can reload it — the restore itself always
/// happens immediately, independent of '적용'/'취소'.
Future<void> showReadingSettingsSheet(
  BuildContext context, {
  VoidCallback? onLibraryRestored,
}) {
  return showDialog(
    context: context,
    builder: (context) =>
        _ReadingSettingsDialog(onLibraryRestored: onLibraryRestored),
  );
}

class _ReadingSettingsDialog extends StatefulWidget {
  final VoidCallback? onLibraryRestored;
  const _ReadingSettingsDialog({this.onLibraryRestored});

  @override
  State<_ReadingSettingsDialog> createState() => _ReadingSettingsDialogState();
}

class _ReadingSettingsDialogState extends State<_ReadingSettingsDialog> {
  late ReadingSettings _draft = ReadingSettingsController.instance.value;
  bool _backingUp = false;
  bool _emailing = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    // Chrome loads its voice list asynchronously, so it may still be empty
    // the moment this dialog opens — rebuild once the real list arrives.
    TtsReader.instance.voicesChanged.addListener(_onVoicesChanged);
  }

  void _onVoicesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TtsReader.instance.voicesChanged.removeListener(_onVoicesChanged);
    super.dispose();
  }

  void _set(ReadingSettings Function(ReadingSettings current) updater) {
    setState(() => _draft = updater(_draft));
  }

  Future<void> _downloadBackup() async {
    setState(() => _backingUp = true);
    try {
      final bytes = await Future(BackupExporter.build);
      if (!mounted) return;
      final uri = await FilePicker.saveFile(
        fileName: BackupExporter.suggestedFileName(),
        bytes: bytes,
        mimeType: 'application/zip',
      );
      if (!mounted || uri == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('backup_done'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('backup_failed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _emailBackup() async {
    setState(() => _emailing = true);
    try {
      final bytes = await Future(BackupExporter.build);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: BackupExporter.suggestedFileName(),
              mimeType: 'application/zip',
            ),
          ],
          subject: tr('backup_email_subject'),
          text: tr('backup_email_body'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('backup_failed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _emailing = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _restoring = true);
    try {
      final file = await pickFileWithWatchdog(allowedExtensions: ['zip']);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final summary = await BackupImporter.restore(bytes);
      if (!mounted) return;
      widget.onLibraryRestored?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('backup_restore_done', {
              'books': '${summary.books}',
              'folders': '${summary.folders}',
              'bookmarks': '${summary.bookmarks}',
              'highlights': '${summary.highlights}',
            }),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('backup_restore_failed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _apply() {
    ReadingSettingsController.instance.update((_) => _draft);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 620 ? size.width * 0.92 : 560.0;
    final dialogHeight = size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: GlassCard(
        opacity: 0.75,
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('reading_settings_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () => _set((_) => ReadingSettings.defaults),
                      child: Text(tr('reset_defaults')),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(tr('language_section')),
                      _LocaleSelector(
                        value: _draft.locale,
                        onChanged: (v) => _set(
                          (s) => s.copyWith(
                            locale: v,
                            appName: appBrandForLocale(v),
                          ),
                        ),
                      ),
                      if (_draft.locale == AppLocale.ko) ...[
                        const SizedBox(height: 16),
                        _SectionLabel(tr('app_name_section')),
                        _AppNameSelector(
                          value: _draft.appName,
                          onChanged: (v) => _set((s) => s.copyWith(appName: v)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _SectionLabel(tr('display_mode')),
                      _ThemeModeSelector(
                        value: _draft.themeMode,
                        onChanged: (v) => _set((s) => s.copyWith(themeMode: v)),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(tr('reading_progress_section')),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('show_progress_title')),
                        subtitle: Text(tr('show_progress_desc')),
                        value: _draft.showProgress,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(showProgress: v)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('show_format_icon_title')),
                        subtitle: Text(tr('show_format_icon_desc')),
                        value: _draft.showFormatIcon,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(showFormatIcon: v)),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(tr('background_color')),
                      _BackgroundSelector(
                        value: _draft.backgroundKey,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(backgroundKey: v)),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(tr('font_section')),
                      _FontSelector(
                        value: _draft.font,
                        weight: _draft.fontWeight,
                        onChanged: (v) => _set((s) => s.copyWith(font: v)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          tr('font_delay_hint'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Theme.of(context).hintColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(tr('weight_section')),
                      _WeightSelector(
                        value: _draft.fontWeight,
                        font: _draft.font,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(fontWeight: v)),
                      ),
                      const SizedBox(height: 12),
                      _SectionLabel(tr('font_size')),
                      _LevelSelector(
                        levels: const [12, 14, 16, 20, 24],
                        value: _draft.fontSize,
                        onChanged: (v) => _set((s) => s.copyWith(fontSize: v)),
                        previewBuilder: (context, v) => Text(
                          '가',
                          style: TextStyle(
                            fontSize: v,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('letter_spacing')),
                      _LevelSelector(
                        levels: const [-1, -0.5, 0, 1, 2],
                        value: _draft.letterSpacing,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(letterSpacing: v)),
                        previewBuilder: (context, v) => Text(
                          '가나',
                          style: TextStyle(fontSize: 15, letterSpacing: v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('line_height')),
                      _LevelSelector(
                        levels: const [1.2, 1.35, 1.5, 1.8, 2.1],
                        value: _draft.lineHeight,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(lineHeight: v)),
                        previewBuilder: (context, v) => Text(
                          '가\n나',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, height: v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('page_margin')),
                      _LevelSelector(
                        levels: const [4, 10, 16, 24, 32],
                        value: _draft.pageMargin,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(pageMargin: v)),
                        previewBuilder: _marginPreview,
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(tr('paragraph_indent')),
                      _LevelSelector(
                        levels: const [0, 8, 16, 24, 32],
                        value: _draft.paragraphIndent,
                        onChanged: (v) =>
                            _set((s) => s.copyWith(paragraphIndent: v)),
                        previewBuilder: _indentPreview,
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(tr('tts_settings')),
                      _TtsVoiceSelector(
                        value: _draft.ttsVoiceUri,
                        onChanged: (v) => _set(
                          (s) => v == null
                              ? s.copyWith(clearTtsVoice: true)
                              : s.copyWith(ttsVoiceUri: v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TtsSpeedSelector(
                        value: _draft.ttsRate,
                        onChanged: (v) => _set((s) => s.copyWith(ttsRate: v)),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(tr('backup_title')),
                      Text(
                        tr('backup_desc'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _backingUp || _emailing
                                  ? null
                                  : _downloadBackup,
                              icon: _backingUp
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.download_outlined),
                              label: Text(
                                tr('backup_download'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _backingUp || _emailing
                                  ? null
                                  : _emailBackup,
                              icon: _emailing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.email_outlined),
                              label: Text(
                                tr('backup_share_email'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('backup_share_email_mobile_only'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('backup_restore_desc'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _restoring ? null : _restoreBackup,
                          icon: _restoring
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.unarchive_outlined),
                          label: Text(
                            tr('backup_restore'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('cancel')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _apply, child: Text(tr('apply'))),
                  ],
                ),
              ),
            ],
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

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
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
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _LocaleSelector extends StatelessWidget {
  final AppLocale value;
  final ValueChanged<AppLocale> onChanged;
  const _LocaleSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final locale in AppLocale.values)
          ChoiceChip(
            label: Text(locale.label),
            selected: value == locale,
            onSelected: (_) => onChanged(locale),
          ),
      ],
    );
  }
}

class _AppNameSelector extends StatelessWidget {
  final AppBrand value;
  final ValueChanged<AppBrand> onChanged;
  const _AppNameSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final brand in AppBrand.values)
          ChoiceChip(
            label: Text(brand.label),
            selected: value == brand,
            onSelected: (_) => onChanged(brand),
          ),
      ],
    );
  }
}

class _BackgroundSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _BackgroundSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final bg in ReadingBackground.presets)
          _BackgroundSwatch(
            background: bg,
            selected: value == bg.key,
            onTap: () => onChanged(bg.key),
          ),
      ],
    );
  }
}

class _BackgroundSwatch extends StatelessWidget {
  final ReadingBackground background;
  final bool selected;
  final VoidCallback onTap;
  const _BackgroundSwatch({
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
            width: 40,
            height: 40,
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

class _FontSelector extends StatelessWidget {
  final ReadingFont value;
  final FontWeight weight;
  final ValueChanged<ReadingFont> onChanged;
  const _FontSelector({
    required this.value,
    required this.weight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final font in ReadingFont.values)
          ChoiceChip(
            label: Text(
              fontLabel(font),
              style: font.baseTextStyle(weight: weight),
            ),
            selected: value == font,
            onSelected: (_) => onChanged(font),
          ),
      ],
    );
  }
}

class _WeightSelector extends StatelessWidget {
  final FontWeight value;
  final ReadingFont font;
  final ValueChanged<FontWeight> onChanged;
  const _WeightSelector({
    required this.value,
    required this.font,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = ReadingWeight.fromFontWeight(value);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final weight in ReadingWeight.values)
          ChoiceChip(
            label: Text(
              weightLabel(weight),
              style: font.baseTextStyle(weight: weight.value),
            ),
            selected: current == weight,
            onSelected: (_) => onChanged(weight.value),
          ),
      ],
    );
  }
}

class _TtsVoiceSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _TtsVoiceSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final voices = TtsReader.instance.voices()
      // Korean voices first (this is a Korean-first reading app), then by
      // language so other locales still group together.
      ..sort((a, b) {
        final aKo = a.lang.toLowerCase().startsWith('ko') ? 0 : 1;
        final bKo = b.lang.toLowerCase().startsWith('ko') ? 0 : 1;
        if (aKo != bKo) return aKo - bKo;
        return a.lang.compareTo(b.lang);
      });

    if (voices.isEmpty) {
      return Text(
        tr('tts_no_voices'),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).hintColor),
      );
    }

    // The stored voiceURI might not match any currently-loaded voice (a
    // different browser/device, or the voice list simply hasn't finished
    // loading yet) — fall back to "system default" display rather than
    // crashing DropdownButton on an unmatched value.
    final selected = value != null && voices.any((v) => v.voiceURI == value)
        ? value
        : null;

    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<String?>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: tr('tts_voice'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(
              tr('tts_voice_system_default'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final voice in voices)
            DropdownMenuItem(
              value: voice.voiceURI,
              child: Text(
                '${voice.name} (${voice.lang})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _TtsSpeedSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _TtsSpeedSelector({required this.value, required this.onChanged});

  static const _steps = [1.0, 1.2, 1.4, 1.6, 1.8, 2.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(tr('tts_speed')),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final step in _steps)
                ChoiceChip(
                  label: Text('x${step.toStringAsFixed(1)}'),
                  selected: (value - step).abs() < 0.01,
                  onSelected: (_) => onChanged(step),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One of the 5 fixed points (매우작게 → 매우 크게) any reading-size setting
/// can be set to, each rendered with a live preview of what it actually
/// looks like instead of a bare number — a slider's "18" or "1.4" means
/// nothing to read at a glance, but a bigger/wider/taller sample does.
const _levelLabelKeys = [
  'level_xs',
  'level_s',
  'level_m',
  'level_l',
  'level_xl',
];

class _LevelSelector extends StatelessWidget {
  final List<double> levels; // exactly 5, matching _levelLabelKeys
  final double value;
  final ValueChanged<double> onChanged;
  final Widget Function(BuildContext context, double value) previewBuilder;

  const _LevelSelector({
    required this.levels,
    required this.value,
    required this.onChanged,
    required this.previewBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Picks the closest preset so a value saved before this UI existed (or
    // restored from an older backup) still highlights a sensible level
    // instead of matching none of the 5.
    var closest = levels.first;
    var bestDiff = (value - closest).abs();
    for (final level in levels) {
      final diff = (value - level).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        closest = level;
      }
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < levels.length; i++)
          _LevelCard(
            label: tr(_levelLabelKeys[i]),
            selected: levels[i] == closest,
            onTap: () => onChanged(levels[i]),
            child: previewBuilder(context, levels[i]),
          ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _LevelCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 36,
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
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

/// A little "page" diagram whose inner colored block shrinks as the margin
/// grows, standing in for [ReadingSettings.pageMargin] since that value has
/// no font attribute to preview directly.
Widget _marginPreview(BuildContext context, double value) {
  final color = Theme.of(context).colorScheme.primary;
  final inset = (value / 48 * 11).clamp(1.0, 12.0);
  return Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(3),
    ),
    padding: EdgeInsets.all(inset),
    child: DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: 0.5)),
    ),
  );
}

/// A two-line paragraph mockup whose first line is offset to match
/// [ReadingSettings.paragraphIndent], since indent has no font attribute
/// to preview directly either.
Widget _indentPreview(BuildContext context, double value) {
  final color = Theme.of(context).colorScheme.primary;
  final indent = (value / 48 * 16).clamp(0.0, 16.0);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.only(left: indent),
        child: Container(width: 20, height: 4, color: color),
      ),
      const SizedBox(height: 3),
      Container(width: 30, height: 4, color: color.withValues(alpha: 0.5)),
    ],
  );
}
