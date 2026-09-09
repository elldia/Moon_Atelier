import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/bookmark_store.dart';
import 'data/folder_store.dart';
import 'data/highlight_store.dart';
import 'data/library_store.dart';
import 'data/markdown_help_store.dart';
import 'data/onboarding_store.dart';
import 'data/reading_settings_controller.dart';
import 'data/reading_settings_store.dart';
import 'screens/splash_screen.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LibraryStore.init();
  await ReadingSettingsStore.init();
  await ReadingSettingsController.init();
  await BookmarkStore.init();
  await HighlightStore.init();
  await FolderStore.init();
  await OnboardingStore.init();
  await MarkdownHelpStore.init();
  runApp(const MyApp());
}

/// A compact, mobile-first (14px base) type scale used throughout the app.
const _textTheme = TextTheme(
  headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  bodyLarge: TextStyle(fontSize: 15),
  bodyMedium: TextStyle(fontSize: 14),
  bodySmall: TextStyle(fontSize: 12),
  labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(fontSize: 12),
  labelSmall: TextStyle(fontSize: 11),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ReadingSettingsController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Moon Atelier',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            scaffoldBackgroundColor: Colors.transparent,
            textTheme: _textTheme,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.transparent,
            textTheme: _textTheme,
          ),
          themeMode: ReadingSettingsController.instance.value.themeMode,
          // Paints the app-wide glass gradient behind every screen so
          // translucent surfaces (app bars, cards, dialogs) have something
          // to visibly frost against.
          builder: (context, child) => GlassBackground(child: child!),
          home: const SplashScreen(),
        );
      },
    );
  }
}
