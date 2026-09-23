import 'package:flutter_test/flutter_test.dart';

import 'package:ebk/models/comic_settings.dart';
import 'package:ebk/models/reading_settings.dart';

/// Guards the exact bug class this session hit twice: a settings field
/// whose fallback in fromMap() (for a save made before that field existed)
/// silently disagreed with the field's own `defaults` value. Every field
/// added to either settings model after its first release needs both of
/// these to agree, or a save from before that field existed resurfaces with
/// the wrong value instead of the current default.
void main() {
  group('ComicSettings', () {
    test('toMap/fromMap round-trips every field unchanged', () {
      const settings = ComicSettings(
        viewMode: ComicViewMode.twoPage,
        readingDirection: ComicReadingDirection.rtl,
        quality: ComicImageQuality.sharp,
        animatePageTurns: false,
        tapZoneDirection: ComicDirection.vertical,
        tapZoneFraction: 0.4,
        backgroundKey: 'white',
        showProgressBar: false,
      );
      final restored = ComicSettings.fromMap(settings.toMap());
      expect(restored.viewMode, settings.viewMode);
      expect(restored.readingDirection, settings.readingDirection);
      expect(restored.quality, settings.quality);
      expect(restored.animatePageTurns, settings.animatePageTurns);
      expect(restored.tapZoneDirection, settings.tapZoneDirection);
      expect(restored.tapZoneFraction, settings.tapZoneFraction);
      expect(restored.backgroundKey, settings.backgroundKey);
      expect(restored.showProgressBar, settings.showProgressBar);
    });

    test('a save made before showProgressBar existed defaults to the '
        'current default, not the opposite', () {
      final legacyMap = ComicSettings.defaults.toMap()
        ..remove('showProgressBar');
      expect(
        ComicSettings.fromMap(legacyMap).showProgressBar,
        ComicSettings.defaults.showProgressBar,
      );
    });
  });

  group('ReadingSettings', () {
    test('toMap/fromMap round-trips showProgress unchanged', () {
      final settings = ReadingSettings.defaults.copyWith(showProgress: true);
      final restored = ReadingSettings.fromMap(settings.toMap());
      expect(restored.showProgress, true);
    });

    test('a save made before showProgress existed falls back to false '
        '(its documented default)', () {
      final legacyMap = ReadingSettings.defaults.toMap()
        ..remove('showProgress');
      expect(
        ReadingSettings.fromMap(legacyMap).showProgress,
        ReadingSettings.defaults.showProgress,
      );
    });
  });
}
