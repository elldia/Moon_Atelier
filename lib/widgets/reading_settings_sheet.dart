import 'package:flutter/material.dart';

import '../data/reading_settings_controller.dart';
import '../l10n/strings.dart';
import '../models/reading_settings.dart';
import '../utils/tts_reader.dart';
import 'glass.dart';

/// Opens the shared reading-preferences dialog. Safe to call from the
/// library screen or from any viewer while reading. Changes are staged
/// locally and only take effect (and persist) once '적용' is pressed —
/// '취소' or tapping outside discards them.
Future<void> showReadingSettingsSheet(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const _ReadingSettingsDialog(),
  );
}

class _ReadingSettingsDialog extends StatefulWidget {
  const _ReadingSettingsDialog();

  @override
  State<_ReadingSettingsDialog> createState() => _ReadingSettingsDialogState();
}

class _ReadingSettingsDialogState extends State<_ReadingSettingsDialog> {
  late ReadingSettings _draft = ReadingSettingsController.instance.value;

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
                      _SliderRow(
                        label: tr('font_size'),
                        value: _draft.fontSize,
                        min: 12,
                        max: 32,
                        valueLabel: _draft.fontSize.round().toString(),
                        onChanged: (v) => _set((s) => s.copyWith(fontSize: v)),
                      ),
                      _SliderRow(
                        label: tr('letter_spacing'),
                        value: _draft.letterSpacing,
                        min: -2,
                        max: 6,
                        divisions: 16,
                        valueLabel: _draft.letterSpacing.toStringAsFixed(1),
                        onChanged: (v) =>
                            _set((s) => s.copyWith(letterSpacing: v)),
                      ),
                      _SliderRow(
                        label: tr('line_height'),
                        value: _draft.lineHeight,
                        min: 1.0,
                        max: 2.4,
                        divisions: 14,
                        valueLabel: _draft.lineHeight.toStringAsFixed(1),
                        onChanged: (v) =>
                            _set((s) => s.copyWith(lineHeight: v)),
                      ),
                      _SliderRow(
                        label: tr('page_margin'),
                        value: _draft.pageMargin,
                        min: 0,
                        max: 48,
                        valueLabel: _draft.pageMargin.round().toString(),
                        onChanged: (v) =>
                            _set((s) => s.copyWith(pageMargin: v)),
                      ),
                      _SliderRow(
                        label: tr('paragraph_indent'),
                        value: _draft.paragraphIndent,
                        min: 0,
                        max: 48,
                        valueLabel: _draft.paragraphIndent.round().toString(),
                        onChanged: (v) =>
                            _set((s) => s.copyWith(paragraphIndent: v)),
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

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 32, child: Text(valueLabel, textAlign: TextAlign.end)),
      ],
    );
  }
}
