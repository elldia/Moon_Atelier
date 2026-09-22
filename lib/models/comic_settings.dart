import 'package:flutter/material.dart';

import 'reading_settings.dart' show ReadingBackground;

/// How many pages are shown at once in the comic viewer.
enum ComicViewMode { single, twoPage }

/// Which axis pages turn/scroll along.
enum ComicDirection { horizontal, vertical }

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

extension ComicDirectionAxis on ComicDirection {
  Axis get axis =>
      this == ComicDirection.horizontal ? Axis.horizontal : Axis.vertical;
}

/// User-adjustable comic-viewer preferences, shared by every comic the user
/// opens (mirrors how [ReadingSettings] is shared by every e-book).
class ComicSettings {
  final ComicViewMode viewMode;
  final ComicDirection direction;
  final ComicImageQuality quality;
  final bool animatePageTurns;

  /// Which edges of the screen count as "tap to turn the page": horizontal
  /// taps the left/right edges, vertical taps the top/bottom edges.
  /// Independent of [direction] — e.g. a vertical continuous-scroll comic
  /// can still use left/right taps to jump a page.
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
    required this.direction,
    required this.quality,
    required this.animatePageTurns,
    required this.tapZoneDirection,
    required this.tapZoneFraction,
    required this.backgroundKey,
  });

  static const defaults = ComicSettings(
    viewMode: ComicViewMode.single,
    direction: ComicDirection.horizontal,
    quality: ComicImageQuality.medium,
    animatePageTurns: true,
    tapZoneDirection: ComicDirection.horizontal,
    tapZoneFraction: 0.3,
    backgroundKey: 'black',
  );

  ReadingBackground get background => ReadingBackground.byKey(backgroundKey);

  ComicSettings copyWith({
    ComicViewMode? viewMode,
    ComicDirection? direction,
    ComicImageQuality? quality,
    bool? animatePageTurns,
    ComicDirection? tapZoneDirection,
    double? tapZoneFraction,
    String? backgroundKey,
  }) {
    return ComicSettings(
      viewMode: viewMode ?? this.viewMode,
      direction: direction ?? this.direction,
      quality: quality ?? this.quality,
      animatePageTurns: animatePageTurns ?? this.animatePageTurns,
      tapZoneDirection: tapZoneDirection ?? this.tapZoneDirection,
      tapZoneFraction: tapZoneFraction ?? this.tapZoneFraction,
      backgroundKey: backgroundKey ?? this.backgroundKey,
    );
  }

  Map<String, dynamic> toMap() => {
    'viewMode': viewMode.name,
    'direction': direction.name,
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
    direction: ComicDirection.values.firstWhere(
      (v) => v.name == raw['direction'],
      orElse: () => ComicDirection.horizontal,
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
