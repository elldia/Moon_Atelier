import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'tts_voice.dart';

/// Thin wrapper around the browser's built-in Web Speech API
/// (`window.speechSynthesis`) — no API key or backend needed. Speaks one
/// piece of text at a time; call [speak] again (or [stop]) to interrupt
/// whatever's currently playing.
class TtsReader {
  TtsReader._() {
    // Chrome (unlike Firefox/Safari) loads its voice list asynchronously —
    // getVoices() can return [] on the very first call. onvoiceschanged
    // fires once the real list is ready; re-broadcast it via a
    // ValueNotifier so UI (the voice picker) can react instead of racing it.
    web.window.speechSynthesis.onvoiceschanged = (web.Event _) {
      voicesChanged.value = !voicesChanged.value;
    }.toJS;
  }
  static final instance = TtsReader._();

  /// Flips every time the browser's voice list (re)loads — not the voices
  /// themselves, just a change pulse for listeners to re-call [voices].
  final voicesChanged = ValueNotifier<bool>(false);

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  // Stored on the instance (rather than captured straight into the
  // utterance's onend/onerror closures) so [stop] can null them out before
  // cancelling -- otherwise a deliberate stop can still fire the
  // just-cancelled utterance's onerror (browsers report a manual cancel as
  // an error event), invoking a stale callback bound to whatever text was
  // playing before the stop, same fix already applied on the native side.
  void Function()? _onDone;
  void Function(String error)? _onError;

  List<TtsVoiceInfo> voices() => web.window.speechSynthesis
      .getVoices()
      .toDart
      .map(
        (v) => TtsVoiceInfo(name: v.name, lang: v.lang, voiceURI: v.voiceURI),
      )
      .toList();

  web.SpeechSynthesisVoice? _rawVoice(String voiceURI) {
    for (final v in web.window.speechSynthesis.getVoices().toDart) {
      if (v.voiceURI == voiceURI) return v;
    }
    return null;
  }

  /// Looks up a previously-picked voice by its [voiceURI] (as persisted in
  /// [ReadingSettings.ttsVoiceUri]). Returns null (meaning "browser default
  /// for the utterance's lang") if [voiceURI] is null or no longer matches
  /// any currently-loaded voice.
  TtsVoiceInfo? findVoice(String? voiceURI) {
    if (voiceURI == null) return null;
    for (final v in voices()) {
      if (v.voiceURI == voiceURI) return v;
    }
    return null;
  }

  /// Speaks [text] aloud. [onDone] fires once the utterance finishes
  /// naturally (not via [stop]); [onError] fires if the browser's speech
  /// engine reports a failure (e.g. no voice available for [lang]).
  void speak(
    String text, {
    String lang = 'ko-KR',
    double rate = 1.0,
    TtsVoiceInfo? voice,
    required void Function() onDone,
    void Function(String error)? onError,
  }) {
    web.window.speechSynthesis.cancel();
    _onDone = null;
    _onError = null;
    if (text.trim().isEmpty) {
      onDone();
      return;
    }
    final utterance = web.SpeechSynthesisUtterance(text)
      ..lang = lang
      ..rate = rate;
    final rawVoice = voice == null ? null : _rawVoice(voice.voiceURI);
    if (rawVoice != null) utterance.voice = rawVoice;
    _speaking = true;
    _onDone = onDone;
    _onError = onError;
    utterance.onend = (web.Event _) {
      _speaking = false;
      final done = _onDone;
      _onDone = null;
      _onError = null;
      done?.call();
    }.toJS;
    utterance.onerror = (web.Event e) {
      _speaking = false;
      final error = _onError;
      _onDone = null;
      _onError = null;
      error?.call('speech synthesis error');
    }.toJS;
    web.window.speechSynthesis.speak(utterance);
  }

  void pause() => web.window.speechSynthesis.pause();

  void resume() => web.window.speechSynthesis.resume();

  void stop() {
    _speaking = false;
    _onDone = null;
    _onError = null;
    web.window.speechSynthesis.cancel();
  }
}
