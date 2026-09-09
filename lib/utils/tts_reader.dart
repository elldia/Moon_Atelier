// Picks the right [TtsReader] implementation for the current platform at
// compile time: the browser's Web Speech API on web, the platform's native
// TTS engine (via `flutter_tts`) everywhere else. Both expose the same
// `TtsReader`/`TtsVoiceInfo` API — see tts_reader_web.dart / tts_reader_io.dart.
export 'tts_reader_io.dart' if (dart.library.js_interop) 'tts_reader_web.dart';
export 'tts_voice.dart';
