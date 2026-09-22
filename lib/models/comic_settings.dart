import 'package:flutter/material.dart';

import 'reading_settings.dart' show ReadingBackground;

/// How many pages are shown at once in the comic viewer.
enum ComicViewMode { single, twoPage }

/// Which edges of the screen a tap zone sits on: horizontal taps the
/// left/right edges, vertical taps the top/bottom edges.
enum ComicDirection { horizontal, vertical }

/// Which way pages turn and, in two-page spreads, which side of the spread
/// each page sits on — matches how the book itself is meant to be read:
/// left-to-right (Western comics) or right-to-left (manga). Page-turning
/// is always horizontal now (see the removed continuous-scroll mode and
/// [ComicViewMode.twoPage]'s forced-horizontal spreads); this only decides
/// which way is "forward".
enum ComicReadingDirection { ltr, rtl }

/// How page images are filtered when Flutter scales them to fit the
/// screen — a tradeoff between crisp pixels and smoothed edges.
enum ComicImageQuality { sharp, medium, smooth }

extension ComicImageQualityFilter on ComicImageQuality {
  FilterQuality get filterQuality => switch (this) {
    ComicImageQuality.sharp => FilterQuality.none,
    ComicImageQuality.medium => FilterQuality.medium,
    ComicImageQuality.smooth => FilterQuality.high,
  };
}

/// User-adjustable comic-viewer preferences, shared by every comic the user
/// opens (mirrors how [ReadingSettings] is shared by every e-book).
class ComicSettings {
  final ComicViewMode viewMode;
  final ComicReadingDirection readingDirection;
  final ComicImageQuality quality;
  final bool animatePageTurns;

  /// Which edges of the screen count as "tap to turn the page" — independent
  /// of [readingDirection], so e.g. top/bottom taps can still be used to
  /// turn pages that read left-to-right.
  final ComicDirection tapZoneDirection;

  /// Fraction (0.2–0.5, picked from a small preset list in Settings) of the
  /// screen's width (or height, in vertical tap zones) that counts as the
  /// "previous"/"next" tap zone on each edge. The remaining middle strip
  /// toggles the reading UI, as before.
  final double tapZoneFraction;

  /// The comic viewer's own background preset (behind/around pages that
  /// don't fill the screen) — separate from [ReadingSettings.backgroundKey]
  /// since the e-book reader and the comic viewer are read independently
  /// and rarely want the same background (e.g. black behind comic pages,
  /// white behind text).
  final String backgroundKey;

  const ComicSettings({
    required this.viewMode,
    required this.readingDirection,
    required this.quality,
    required this.animatePageTurns,
    required this.tapZoneDirection,
    required this.tapZoneFraction,
    required this.backgroundKey,
  });

  static const defaults = ComicSettings(
    viewMode: ComicViewMode.single,
    readingDirection: ComicReadingDirection.ltr,
    quality: ComicImageQuality.medium,
    animatePageTurns: true,
    tapZoneDirection: ComicDirection.horizontal,
    tapZoneFraction: 0.3,
    backgroundKey: 'black',
  );

  ReadingBackground get background => ReadingBackground.byKey(backgroundKey);

  ComicSettings copyWith({
    ComicViewMode? viewMode,
    ComicReadingDirection? readingDirection,
    ComicImageQuality? quality,
    bool? animatePageTurns,
    ComicDirection? tapZoneDirection,
    double? tapZoneFraction,
    String? backgroundKey,
  }) {
    return ComicSettings(
      viewMode: viewMode ?? this.viewMode,
      readingDirection: readingDirection ?? this.readingDirection,
      quality: quality ?? this.quality,
      animatePageTurns: animatePageTurns ?? this.animatePageTurns,
      tapZoneDirection: tapZoneDirection ?? this.tapZoneDirection,
      tapZoneFraction: tapZoneFraction ?? this.tapZoneFraction,
      backgroundKey: backgroundKey ?? this.backgroundKey,
    );
  }

  Map<String, dynamic> toMap() => {
    'viewMode': viewMode.name,
    'readingDirection': readingDirection.name,
    'quality': quality.name,
    'animatePageTurns': animatePageTurns,
    'tapZoneDirection': tapZoneDirection.name,
    'tapZoneFraction': tapZoneFraction,
    'backgroundKey': backgroundKey,
  };

  factory ComicSettings.fromMap(Map raw) => ComicSettings(
    viewMode: ComicViewMode.values.firstWhere(
      (v) => v.name == raw['viewMode'],
      orElse: () => ComicViewMode.single,
    ),
    readingDirection: ComicReadingDirection.values.firstWhere(
      (v) => v.name == raw['readingDirection'],
      orElse: () => ComicReadingDirection.ltr,
    ),
    quality: ComicImageQuality.values.firstWhere(
      (v) => v.name == raw['quality'],
      orElse: () => ComicImageQuality.medium,
    ),
    animatePageTurns: raw['animatePageTurns'] as bool? ?? true,
    tapZoneDirection: ComicDirection.values.firstWhere(
      (v) => v.name == raw['tapZoneDirection'],
      orElse: () => ComicDirection.horizontal,
    ),
    tapZoneFraction: ((raw['tapZoneFraction'] as num?) ?? 0.3).toDouble().clamp(
      0.2,
      0.5,
    ),
    backgroundKey: raw['backgroundKey'] as String? ?? 'black',
  );
}
