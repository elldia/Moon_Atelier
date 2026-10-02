import 'package:ebk/data/reading_settings_controller.dart';
import 'package:ebk/models/reading_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_turn_harness.dart';

// The reading settings sheet's five levels for each layout option.
const _fontSizes = [12.0, 14.0, 16.0, 20.0, 24.0];
const _lineHeights = [1.2, 1.35, 1.5, 1.8, 2.1];
const _letterSpacings = [-1.0, -0.5, 0.0, 1.0, 2.0];
const _margins = [4.0, 10.0, 16.0, 24.0, 32.0];
const _indents = [0.0, 8.0, 16.0, 24.0, 32.0];

ReadingSettings _settings({
  double? fontSize,
  double? lineHeight,
  double? letterSpacing,
  double? pageMargin,
  double? paragraphIndent,
}) => ReadingSettings.defaults.copyWith(
  readingMode: ReadingMode.page,
  fontSize: fontSize,
  lineHeight: lineHeight,
  letterSpacing: letterSpacing,
  pageMargin: pageMargin,
  paragraphIndent: paragraphIndent,
);

String _describe(ReadingSettings s) =>
    'size ${s.fontSize} line ${s.lineHeight} spacing ${s.letterSpacing} '
    'margin ${s.pageMargin} indent ${s.paragraphIndent}';

/// Every level of each option on its own (others at their defaults), then
/// the extremes and two mixed combinations.
List<ReadingSettings> _textCombos() => [
  for (final v in _fontSizes) _settings(fontSize: v),
  for (final v in _lineHeights) _settings(lineHeight: v),
  for (final v in _letterSpacings) _settings(letterSpacing: v),
  for (final v in _margins) _settings(pageMargin: v),
  for (final v in _indents) _settings(paragraphIndent: v),
  _settings(
    fontSize: _fontSizes.first,
    lineHeight: _lineHeights.first,
    letterSpacing: _letterSpacings.first,
    pageMargin: _margins.first,
    paragraphIndent: _indents.first,
  ),
  _settings(
    fontSize: _fontSizes.last,
    lineHeight: _lineHeights.last,
    letterSpacing: _letterSpacings.last,
    pageMargin: _margins.last,
    paragraphIndent: _indents.last,
  ),
  _settings(
    fontSize: _fontSizes.last,
    lineHeight: _lineHeights.first,
    letterSpacing: _letterSpacings.last,
    pageMargin: _margins.first,
    paragraphIndent: _indents.last,
  ),
  _settings(
    fontSize: _fontSizes.first,
    lineHeight: _lineHeights.last,
    letterSpacing: _letterSpacings.first,
    pageMargin: _margins.last,
    paragraphIndent: _indents.first,
  ),
];

/// The extremes of each option, plus all-min and all-max.
List<ReadingSettings> _epubCombos() => [
  _settings(fontSize: _fontSizes.first),
  _settings(fontSize: _fontSizes.last),
  _settings(lineHeight: _lineHeights.first),
  _settings(lineHeight: _lineHeights.last),
  _settings(letterSpacing: _letterSpacings.first),
  _settings(letterSpacing: _letterSpacings.last),
  _settings(pageMargin: _margins.first),
  _settings(pageMargin: _margins.last),
  _settings(paragraphIndent: _indents.last),
  _settings(
    fontSize: _fontSizes.last,
    lineHeight: _lineHeights.last,
    letterSpacing: _letterSpacings.last,
    pageMargin: _margins.last,
    paragraphIndent: _indents.last,
  ),
];

// A phone, and roughly a 7" e-reader's logical screen.
const _screens = [Size(400, 800), Size(632, 840)];

void main() {
  setUpAll(initReaderStores);
  tearDown(() {
    ReadingSettingsController.instance.value = ReadingSettings.defaults;
  });

  for (final screen in _screens) {
    for (final settings in _textCombos()) {
      testWidgets('text, ${screen.width.toInt()}x${screen.height.toInt()}, '
          '${_describe(settings)}', (tester) async {
        ReadingSettingsController.instance.value = settings;
        await pumpTextReader(tester, size: screen);
        await walkPagesBothWays(tester, turns: 8);
      });
    }
  }

  for (final settings in _epubCombos()) {
    testWidgets('EPUB, ${_describe(settings)}', (tester) async {
      ReadingSettingsController.instance.value = settings;
      await pumpEpubReader(tester);
      await walkPagesBothWays(tester, turns: 6);
    });
  }
}
