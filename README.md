# Moon Atelier (달빛서재)

A Flutter web ebook reader.

## Features

- Formats: EPUB, PDF, TXT, DOCX, RTF, MusicXML/MXL
- Customizable reading settings: font, weight, size, letter-spacing, line-height,
  margins, indent, background presets, and light/dark/system theme
- Highlights and bookmarks while reading
- Folders, sorting, search, and multi-select delete in the library
- Glassmorphism UI, responsive down to 320px width
- Interface localization: 한국어 / English / 日本語 / 中文

## Getting started

```
flutter pub get
flutter run -d web-server --web-port=8765 --web-hostname=0.0.0.0
```

This project bundles a locally patched copy of `pdfx` under `vendor/pdfx`
(see `pubspec.yaml`'s `dependency_overrides`) to enable mouse-wheel zoom on
the PDF viewer, which upstream `pdfx` does not expose.
