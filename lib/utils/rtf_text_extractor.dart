import 'dart:convert';
import 'dart:typed_data';

import 'package:cp949_codec/cp949_codec.dart';

/// Extracts plain text from an .rtf file's bytes.
///
/// RTF control syntax is always plain ASCII; non-ASCII text is carried
/// either as `\'hh` hex-escaped bytes (interpreted using the document's
/// `\ansicpg` codepage, e.g. 949 for Korean CP949/EUC-KR) or as `\uN`
/// Unicode escapes. This walks the token stream directly rather than
/// going through a general-purpose RTF library, since only readable
/// text needs to survive.
String extractRtfText(Uint8List bytes) {
  // The control stream itself is ASCII, so decoding as latin1 first keeps
  // every byte addressable 1:1 while we look for control words vs. text.
  final raw = latin1.decode(bytes);
  final len = raw.length;

  final buffer = StringBuffer();
  final skipStack = <bool>[false];

  Encoding textEncoding = latin1;
  var uc = 1;
  var skipFallback = 0;
  var hexBytes = <int>[];

  bool skipping() => skipStack[skipStack.length - 1];

  void flushHexBytes() {
    if (hexBytes.isEmpty) return;
    final chunk = hexBytes;
    hexBytes = [];
    if (skipFallback > 0) {
      skipFallback--;
    } else if (!skipping()) {
      try {
        buffer.write(textEncoding.decode(chunk));
      } on FormatException {
        buffer.write(latin1.decode(chunk));
      }
    }
  }

  void emitChar(String ch) {
    if (skipFallback > 0) {
      skipFallback--;
    } else if (!skipping()) {
      buffer.write(ch);
    }
  }

  void handleControlWord(String word, int? param) {
    switch (word) {
      case 'par':
      case 'line':
      case 'row':
        emitChar('\n');
        break;
      case 'tab':
        emitChar('\t');
        break;
      case 'ansicpg':
        if (param != null) {
          textEncoding = switch (param) {
            949 => cp949,
            65001 => utf8,
            _ => latin1,
          };
        }
        break;
      case 'uc':
        if (param != null) uc = param;
        break;
      case 'u':
        if (param != null) {
          var codeUnit = param;
          if (codeUnit < 0) codeUnit += 65536;
          if (!skipping()) buffer.writeCharCode(codeUnit);
          skipFallback = uc;
        }
        break;
      case 'fonttbl':
      case 'colortbl':
      case 'stylesheet':
      case 'info':
      case 'generator':
      case 'pict':
      case 'object':
      case 'header':
      case 'footer':
      case 'footnote':
      case 'themedata':
      case 'colorschememapping':
      case 'datastore':
      case 'listtable':
      case 'listoverridetable':
      case 'rsidtbl':
      case '*':
        skipStack[skipStack.length - 1] = true;
        break;
      default:
        break;
    }
  }

  bool isAsciiLetter(int code) =>
      (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  bool isAsciiDigit(int code) => code >= 0x30 && code <= 0x39;

  var i = 0;
  while (i < len) {
    final code = raw.codeUnitAt(i);

    if (code == 0x5C) {
      // backslash
      if (i + 1 >= len) break;
      final next = raw[i + 1];
      if (next == '\\' || next == '{' || next == '}') {
        flushHexBytes();
        emitChar(next);
        i += 2;
        continue;
      }
      if (next == "'") {
        if (i + 3 < len) {
          final byte = int.tryParse(raw.substring(i + 2, i + 4), radix: 16);
          if (byte != null) hexBytes.add(byte);
        }
        i += 4;
        continue;
      }
      if (next == '\n' || next == '\r') {
        flushHexBytes();
        i += 2;
        continue;
      }
      if (next == '~') {
        flushHexBytes();
        emitChar(' ');
        i += 2;
        continue;
      }
      if (next == '-' || next == '_' || next == ':' || next == '*') {
        // optional hyphen / nonbreaking hyphen / misc control symbols:
        // no visible text of their own (handled as control words above
        // for the ones that matter, e.g. `\*`).
        flushHexBytes();
        if (next == '*') {
          handleControlWord('*', null);
        }
        i += 2;
        continue;
      }
      if (!isAsciiLetter(next.codeUnitAt(0))) {
        // Unknown control symbol: consume just the symbol.
        flushHexBytes();
        i += 2;
        continue;
      }

      // Control word: letters, optional signed numeric parameter, then
      // a single optional trailing space delimiter.
      flushHexBytes();
      var j = i + 1;
      final wordStart = j;
      while (j < len && isAsciiLetter(raw.codeUnitAt(j))) {
        j++;
      }
      final word = raw.substring(wordStart, j);

      int? param;
      if (j < len && (raw[j] == '-' || isAsciiDigit(raw.codeUnitAt(j)))) {
        final numStart = j;
        if (raw[j] == '-') j++;
        while (j < len && isAsciiDigit(raw.codeUnitAt(j))) {
          j++;
        }
        param = int.tryParse(raw.substring(numStart, j));
      }
      if (j < len && raw[j] == ' ') j++;

      handleControlWord(word, param);
      i = j;
      continue;
    }

    if (code == 0x7B) {
      // {
      flushHexBytes();
      skipStack.add(skipping());
      i++;
      continue;
    }
    if (code == 0x7D) {
      // }
      flushHexBytes();
      if (skipStack.length > 1) skipStack.removeLast();
      i++;
      continue;
    }
    if (code == 0x0A || code == 0x0D) {
      // Raw newlines in the source stream are formatting whitespace
      // between tokens, not paragraph breaks (`\par` handles those).
      i++;
      continue;
    }

    flushHexBytes();
    emitChar(raw[i]);
    i++;
  }
  flushHexBytes();

  return buffer
      .toString()
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
