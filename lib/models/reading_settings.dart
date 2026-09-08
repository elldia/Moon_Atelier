import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's interface language (independent of reading content, which
/// stays whatever language the book itself is in).
enum AppLocale {
  ko('한국어'),
  en('English'),
  ja('日本語'),
  zh('中文');

  final String label;
  const AppLocale(this.label);

  Locale get locale => Locale(name);
}

/// The app's own display name. Automatically follows [AppLocale]: Korean
/// shows the Korean brand, every other interface language shows the
/// international one. See [appBrandForLocale].
enum AppBrand {
  moonAtelier('Moon Atelier'),
  moonlightLibrary('달빛서재');

  final String label;
  const AppBrand(this.label);
}

/// The app name that should be shown for a given interface [locale] —
/// Korean gets the Korean brand, everything else gets the international
/// one. Call this whenever [AppLocale] changes to keep [ReadingSettings]'s
/// stored `appName` in sync.
AppBrand appBrandForLocale(AppLocale locale) =>
    locale == AppLocale.ko ? AppBrand.moonlightLibrary : AppBrand.moonAtelier;

/// A curated, Korean-reading-friendly font list. The key is what gets
/// persisted; [label] is shown in the settings UI. Pretendard and MaruBuri
/// aren't on Google Fonts, so they ship as bundled local assets (see
/// pubspec.yaml `flutter.fonts`) instead of going through [GoogleFonts].
enum ReadingFont {
  system('시스템 기본'),
  notoSansKr('노토 산스'),
  pretendard('프리텐다드'),
  maruBuri('마루부리'),
  notoSerifKr('노토 세리프'),
  nanumGothic('나눔고딕'),
  nanumMyeongjo('나눔명조'),
  gowunBatang('고운바탕'),
  gowunDodum('고운돋움'),
  ibmPlexSansKr('IBM 플렉스 산스');

  final String label;
  const ReadingFont(this.label);

  TextStyle baseTextStyle({required FontWeight weight}) {
    switch (this) {
      case ReadingFont.system:
        return TextStyle(fontWeight: weight);
      case ReadingFont.pretendard:
        return TextStyle(fontFamily: 'Pretendard', fontWeight: weight);
      case ReadingFont.maruBuri:
        return TextStyle(fontFamily: 'MaruBuri', fontWeight: weight);
      case ReadingFont.notoSansKr:
        return GoogleFonts.notoSansKr(fontWeight: weight);
      case ReadingFont.notoSerifKr:
        return GoogleFonts.notoSerifKr(fontWeight: weight);
      case ReadingFont.nanumGothic:
        return GoogleFonts.nanumGothic(fontWeight: weight);
      case ReadingFont.nanumMyeongjo:
        return GoogleFonts.nanumMyeongjo(fontWeight: weight);
      case ReadingFont.gowunBatang:
        return GoogleFonts.gowunBatang(fontWeight: weight);
      case ReadingFont.gowunDodum:
        return GoogleFonts.gowunDodum(fontWeight: weight);
      case ReadingFont.ibmPlexSansKr:
        return GoogleFonts.ibmPlexSansKr(fontWeight: weight);
    }
  }
}

/// Selectable text weights. Kept to a small, universally-supported set
/// rather than the full 100-900 range so every bundled/Google font renders
/// a sensible face for each option.
enum ReadingWeight {
  light('가늘게', FontWeight.w300),
  regular('보통', FontWeight.w400),
  medium('중간', FontWeight.w500),
  semiBold('약간 굵게', FontWeight.w600),
  bold('굵게', FontWeight.w700);

  final String label;
  final FontWeight value;
  const ReadingWeight(this.label, this.value);

  static ReadingWeight fromFontWeight(FontWeight weight) =>
      ReadingWeight.values.firstWhere(
        (w) => w.value == weight,
        orElse: () => ReadingWeight.regular,
      );
}

/// A selectable reading-background preset. Text color is derived from the
/// background's luminance rather than stored separately, so every preset
/// stays readable without a second color knob.
class ReadingBackground {
  final String key;
  final String label;
  final Color color;

  const ReadingBackground(this.key, this.label, this.color);

  Color get textColor => color.computeLuminance() > 0.4
      ? const Color(0xFF262220)
      : const Color(0xFFE8E3DD);

  static const presets = [
    ReadingBackground('white', '화이트', Color(0xFFFFFFFF)),
    ReadingBackground('sepia', '세피아', Color(0xFFF5ECD9)),
    ReadingBackground('gray', '그레이', Color(0xFFDCDCDC)),
    ReadingBackground('dark', '다크', Color(0xFF262626)),
    ReadingBackground('black', '블랙', Color(0xFF000000)),
  ];

  static ReadingBackground byKey(String key) =>
      presets.firstWhere((p) => p.key == key, orElse: () => presets.first);
}

/// User-adjustable reading preferences, shared by every text-based viewer
/// (TXT/DOCX/RTF and EPUB) and by the app's overall light/dark theme.
class ReadingSettings {
  final ReadingFont font;
  final FontWeight fontWeight;
  final double fontSize;
  final double letterSpacing;
  final double lineHeight;
  final double pageMargin;
  final double paragraphIndent;
  final String backgroundKey;
  final ThemeMode themeMode;
  final bool showProgress;
  final AppLocale locale;
  final AppBrand appName;
  final bool showFormatIcon;

  const ReadingSettings({
    required this.font,
    required this.fontWeight,
    required this.fontSize,
    required this.letterSpacing,
    required this.lineHeight,
    required this.pageMargin,
    required this.paragraphIndent,
    required this.backgroundKey,
    required this.themeMode,
    required this.showProgress,
    required this.locale,
    required this.appName,
    required this.showFormatIcon,
  });

  static const defaults = ReadingSettings(
    font: ReadingFont.system,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    letterSpacing: 0,
    lineHeight: 1.5,
    pageMargin: 16,
    paragraphIndent: 0,
    backgroundKey: 'white',
    themeMode: ThemeMode.system,
    showProgress: true,
    locale: AppLocale.ko,
    appName: AppBrand.moonlightLibrary,
    showFormatIcon: true,
  );

  ReadingBackground get background => ReadingBackground.byKey(backgroundKey);

  /// Base text style for reading content: [font]/[fontWeight] with this
  /// settings' size, spacing, line height, and background-derived color.
  TextStyle get textStyle => font
      .baseTextStyle(weight: fontWeight)
      .copyWith(
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        height: lineHeight,
        color: background.textColor,
      );

  ReadingSettings copyWith({
    ReadingFont? font,
    FontWeight? fontWeight,
    double? fontSize,
    double? letterSpacing,
    double? lineHeight,
    double? pageMargin,
    double? paragraphIndent,
    String? backgroundKey,
    ThemeMode? themeMode,
    bool? showProgress,
    AppLocale? locale,
    AppBrand? appName,
    bool? showFormatIcon,
  }) {
    return ReadingSettings(
      font: font ?? this.font,
      fontWeight: fontWeight ?? this.fontWeight,
      fontSize: fontSize ?? this.fontSize,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      pageMargin: pageMargin ?? this.pageMargin,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      backgroundKey: backgroundKey ?? this.backgroundKey,
      themeMode: themeMode ?? this.themeMode,
      showProgress: showProgress ?? this.showProgress,
      locale: locale ?? this.locale,
      appName: appName ?? this.appName,
      showFormatIcon: showFormatIcon ?? this.showFormatIcon,
    );
  }

  Map<String, dynamic> toMap() => {
    'font': font.name,
    'fontWeight': fontWeight.value,
    'fontSize': fontSize,
    'letterSpacing': letterSpacing,
    'lineHeight': lineHeight,
    'pageMargin': pageMargin,
    'paragraphIndent': paragraphIndent,
    'backgroundKey': backgroundKey,
    'themeMode': themeMode.name,
    'showProgress': showProgress,
    'locale': locale.name,
    'appName': appName.name,
    'showFormatIcon': showFormatIcon,
  };

  factory ReadingSettings.fromMap(Map raw) => ReadingSettings(
    font: ReadingFont.values.byName(raw['font'] as String),
    fontWeight: FontWeight.values.firstWhere(
      (w) => w.value == raw['fontWeight'] as int,
      orElse: () => FontWeight.w400,
    ),
    fontSize: (raw['fontSize'] as num).toDouble(),
    letterSpacing: (raw['letterSpacing'] as num).toDouble(),
    lineHeight: (raw['lineHeight'] as num).toDouble(),
    pageMargin: (raw['pageMargin'] as num).toDouble(),
    paragraphIndent: (raw['paragraphIndent'] as num).toDouble(),
    backgroundKey: raw['backgroundKey'] as String,
    themeMode: ThemeMode.values.byName(raw['themeMode'] as String),
    showProgress: raw['showProgress'] as bool? ?? true,
    locale: AppLocale.values.firstWhere(
      (l) => l.name == raw['locale'],
      orElse: () => AppLocale.ko,
    ),
    appName: AppBrand.values.firstWhere(
      (a) => a.name == raw['appName'],
      orElse: () => AppBrand.moonAtelier,
    ),
    showFormatIcon: raw['showFormatIcon'] as bool? ?? true,
  );
}
