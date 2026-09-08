import 'dart:convert';
import 'dart:typed_data';

import 'package:cp949_codec/cp949_codec.dart';

/// Decodes raw bytes to text, auto-detecting UTF-8 vs CP949 (EUC-KR) — the
/// two most common encodings for plain-text Korean files (many older
/// Korean web novels/documents are saved as CP949). Tries strict UTF-8
/// first; genuine CP949 byte sequences essentially never also happen to be
/// valid UTF-8, so a decode failure reliably signals CP949 instead of
/// silently mojibake-ing through as malformed UTF-8.
String decodeTextBytes(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    try {
      return cp949.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}
