import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared glassmorphism building blocks: frosted, translucent surfaces with
/// a soft blur and a hairline border, used for every card/app bar/dialog in
/// the app so the look stays consistent.
const glassRadius = 20.0;

Color glassSurface(BuildContext context, {double opacity = 0.45}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return (dark ? Colors.black : Colors.white).withValues(alpha: opacity);
}

Color glassBorder(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return (dark ? Colors.white : Colors.white).withValues(
    alpha: dark ? 0.12 : 0.55,
  );
}

/// A frosted card: blurred backdrop, translucent fill, thin light border,
/// soft shadow, rounded corners.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = EdgeInsets.zero,
    this.radius = glassRadius,
    this.opacity = 0.45,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: glassSurface(context, opacity: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // ListTile/InkWell descendants need a Material ancestor to paint
          // ink splashes on; without one directly inside this colored box,
          // Flutter warns the splash may render invisibly (painted behind
          // the color instead of on top of it).
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

/// A frosted app bar: same translucent-blur treatment as [GlassCard], used
/// via [AppBar.flexibleSpace] so the page content blurs through it while
/// scrolling underneath.
AppBar glassAppBar(
  BuildContext context, {
  Widget? title,
  Widget? leading,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    title: title,
    leading: leading,
    actions: actions,
    bottom: bottom,
    backgroundColor: glassSurface(context, opacity: 0.55),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

/// The app-wide soft gradient painted behind every screen (via
/// [MaterialApp.builder]) so glass surfaces have something to visibly
/// frost against.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF1A1625), Color(0xFF16202B), Color(0xFF1B1420)]
              : const [Color(0xFFEFE7FB), Color(0xFFE3EEFB), Color(0xFFF7E9F3)],
        ),
      ),
      child: child,
    );
  }
}
