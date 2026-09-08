import 'package:flutter/material.dart';

/// A user-selected snippet of text saved from a book while reading (TXT,
/// DOCX and RTF only — plain-text viewer chunks give clean character
/// offsets to highlight against; EPUB/PDF don't expose that here).
///
/// [chunkIndex]/[start]/[end] locate the snippet within the viewer's
/// paragraph chunks so it can be re-rendered with a highlight background
/// and scrolled back into view later. [color] is the highlighter color the
/// user picked when saving it.
class Highlight {
  final String id;
  final String bookId;
  final int chunkIndex;
  final int start;
  final int end;
  final String text;
  final Color color;
  final DateTime createdAt;

  const Highlight({
    required this.id,
    required this.bookId,
    required this.chunkIndex,
    required this.start,
    required this.end,
    required this.text,
    required this.color,
    required this.createdAt,
  });

  static const defaultColor = Color(0x66FFEB3B);

  Map<String, dynamic> toMap() => {
    'bookId': bookId,
    'chunkIndex': chunkIndex,
    'start': start,
    'end': end,
    'text': text,
    'color': color.toARGB32(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Highlight.fromMap(String id, Map raw) => Highlight(
    id: id,
    bookId: raw['bookId'] as String,
    chunkIndex: raw['chunkIndex'] as int,
    start: raw['start'] as int,
    end: raw['end'] as int,
    text: raw['text'] as String,
    color: raw['color'] != null ? Color(raw['color'] as int) : defaultColor,
    createdAt: DateTime.parse(raw['createdAt'] as String),
  );
}
