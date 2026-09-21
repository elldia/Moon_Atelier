import 'package:flutter/material.dart';

/// How many pages are shown at once in the comic viewer.
enum ComicViewMode { single, twoPage, continuousScroll }

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

  const ComicSettings({
    required this.viewMode,
    required this.direction,
    required this.quality,
  });

  static const defaults = ComicSettings(
    viewMode: ComicViewMode.single,
    direction: ComicDirection.horizontal,
    quality: ComicImageQuality.medium,
  );

  ComicSettings copyWith({
    ComicViewMode? viewMode,
    ComicDirection? direction,
    ComicImageQuality? quality,
  }) {
    return ComicSettings(
      viewMode: viewMode ?? this.viewMode,
      direction: direction ?? this.direction,
      quality: quality ?? this.quality,
    );
  }

  Map<String, dynamic> toMap() => {
    'viewMode': viewMode.name,
    'direction': direction.name,
    'quality': quality.name,
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
  );
}
