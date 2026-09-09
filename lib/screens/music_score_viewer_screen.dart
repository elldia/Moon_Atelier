// Picks the right `MusicScoreViewerScreen` implementation for the current
// platform at compile time: OpenSheetMusicDisplay embedded directly as a
// web platform view on web, the same JS library reused inside a
// `webview_flutter` view on native platforms -- see
// music_score_viewer_screen_web.dart / music_score_viewer_screen_io.dart.
export 'music_score_viewer_screen_io.dart'
    if (dart.library.js_interop) 'music_score_viewer_screen_web.dart';
