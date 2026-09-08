import 'package:flutter/material.dart';

import '../widgets/glass.dart';
import 'library_screen.dart';

/// Shown for ~1.5s on every fresh launch/refresh before handing off to
/// [LibraryScreen] — just the app icon over the app's gradient background,
/// so the transition into the real UI feels intentional rather than a
/// blank flash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.85 + 0.15 * value, child: child),
            ),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 120,
              height: 120,
            ),
          ),
        ),
      ),
    );
  }
}
