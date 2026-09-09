/// A voice available to [TtsReader], normalized across the browser's Web
/// Speech API (web) and the platform's native TTS engine (Android/iOS/
/// desktop) so the rest of the app doesn't need to know which one is active.
class TtsVoiceInfo {
  final String name;
  final String lang;

  /// Stable identifier for persisting the user's choice (as
  /// [ReadingSettings.ttsVoiceUri]) and looking it back up via
  /// [TtsReader.findVoice].
  final String voiceURI;

  const TtsVoiceInfo({
    required this.name,
    required this.lang,
    required this.voiceURI,
  });
}
