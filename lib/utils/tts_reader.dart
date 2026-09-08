import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Thin wrapper around the browser's built-in Web Speech API
/// (`window.speechSynthesis`) — no API key or backend needed. Speaks one
/// piece of text at a time; call [speak] again (or [stop]) to interrupt
/// whatever's currently playing.
class TtsReader {
  TtsReader._();
  static final instance = TtsReader._();

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  /// Speaks [text] aloud. [onDone] fires once the utterance finishes
  /// naturally (not via [stop]); [onError] fires if the browser's speech
  /// engine reports a failure (e.g. no voice available for [lang]).
  void speak(
    String text, {
    String lang = 'ko-KR',
    double rate = 1.0,
    required void Function() onDone,
    void Function(String error)? onError,
  }) {
    web.window.speechSynthesis.cancel();
    if (text.trim().isEmpty) {
      onDone();
      return;
    }
    final utterance = web.SpeechSynthesisUtterance(text)
      ..lang = lang
      ..rate = rate;
    _speaking = true;
    utterance.onend = (web.Event _) {
      _speaking = false;
      onDone();
    }.toJS;
    utterance.onerror = (web.Event e) {
      _speaking = false;
      onError?.call('speech synthesis error');
    }.toJS;
    web.window.speechSynthesis.speak(utterance);
  }

  void pause() => web.window.speechSynthesis.pause();

  void resume() => web.window.speechSynthesis.resume();

  void stop() {
    _speaking = false;
    web.window.speechSynthesis.cancel();
  }
}
