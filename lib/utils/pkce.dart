import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _codeVerifierChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/// A random 64-character PKCE code verifier (RFC 7636 allows 43-128), from
/// the RFC's own unreserved-character alphabet.
String generateCodeVerifier() {
  final rand = Random.secure();
  return List.generate(
    64,
    (_) => _codeVerifierChars[rand.nextInt(_codeVerifierChars.length)],
  ).join();
}

/// The S256 code challenge for [verifier]: unpadded base64url of its
/// SHA-256 digest.
String codeChallengeFor(String verifier) => base64Url
    .encode(sha256.convert(utf8.encode(verifier)).bytes)
    .replaceAll('=', '');
