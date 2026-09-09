import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_voice.dart';

/// Native (Android/iOS/desktop) counterpart of the web build's
/// `tts_reader_web.dart`, backed by the platform's own TTS engine via
/// `flutter_tts` instead of the browser's Web Speech API.
class TtsReader {
  TtsReader._() {
    _tts.setCompletionHandler(() {
      _speaking = false;
      final done = _onDone;
      _onDone = null;
      _onError = null;
      done?.call();
    });
    _tts.setCancelHandler(() {
      _speaking = false;
      _onDone = null;
      _onError = null;
    });
    _tts.setErrorHandler((dynamic message) {
      _speaking = false;
      final error = _onError;
      _onDone = null;
      _onError = null;
      error?.call('$message');
    });
    _loadVoices();
  }
  static final instance = TtsReader._();

  final _tts = FlutterTts();

  /// Flips once the platform's voice list has loaded, mirroring the web
  /// build's async `onvoiceschanged` pulse.
  final voicesChanged = ValueNotifier<bool>(false);

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  void Function()? _onDone;
  void Function(String error)? _onError;

  List<TtsVoiceInfo> _voices = [];

  Future<void> _loadVoices() async {
    try {
      final raw = await _tts.getVoices as List<dynamic>;
      _voices = raw
          .map((entry) {
            final map = Map<Object?, Object?>.from(entry as Map);
            final name = map['name']?.toString() ?? '';
            final locale = map['locale']?.toString() ?? '';
            return TtsVoiceInfo(name: name, lang: locale, voiceURI: name);
          })
          // A blank name means the platform gave us nothing usable.
          .where((v) => v.name.isNotEmpty)
          .toList();
    } catch (_) {
      _voices = [];
    }
    voicesChanged.value = !voicesChanged.value;
  }

  List<TtsVoiceInfo> voices() => _voices;

  /// Looks up a previously-picked voice by its [voiceURI] (as persisted in
  /// [ReadingSettings.ttsVoiceUri]). Returns null (meaning "platform default
  /// for the utterance's lang") if [voiceURI] is null or no longer matches
  /// any currently-loaded voice.
  TtsVoiceInfo? findVoice(String? voiceURI) {
    if (voiceURI == null) return null;
    for (final v in _voices) {
      if (v.voiceURI == voiceURI) return v;
    }
    return null;
  }

  /// Speaks [text] aloud. [onDone] fires once the utterance finishes
  /// naturally (not via [stop]); [onError] fires if the platform's TTS
  /// engine reports a failure (e.g. no voice available for [lang]).
  void speak(
    String text, {
    String lang = 'ko-KR',
    double rate = 1.0,
    TtsVoiceInfo? voice,
    required void Function() onDone,
    void Function(String error)? onError,
  }) {
    unawaited(_speak(text, lang: lang, rate: rate, voice: voice));
    _onDone = onDone;
    _onError = onError;
  }

  Future<void> _speak(
    String text, {
    required String lang,
    required double rate,
    TtsVoiceInfo? voice,
  }) async {
    await _tts.stop();
    if (text.trim().isEmpty) {
      _speaking = false;
      final done = _onDone;
      _onDone = null;
      _onError = null;
      done?.call();
      return;
    }
    await _tts.setLanguage(voice?.lang ?? lang);
    // flutter_tts normalizes speech rate to 0.0-1.0 (~0.5 is a platform's
    // "normal" speed) across engines, unlike the web build's 1.0 = normal.
    await _tts.setSpeechRate((rate / 2.0).clamp(0.1, 1.0));
    if (voice != null) {
      await _tts.setVoice({'name': voice.name, 'locale': voice.lang});
    }
    _speaking = true;
    await _tts.speak(text);
  }

  void pause() {
    unawaited(_tts.pause());
  }

  // flutter_tts has no true resume — pausing mid-utterance on most engines
  // effectively stops it, so there's nothing meaningful to resume into.
  void resume() {}

  void stop() {
    _speaking = false;
    _onDone = null;
    _onError = null;
    unawaited(_tts.stop());
  }
}
