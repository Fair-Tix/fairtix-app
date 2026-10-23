import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Smooth page transitions for the web (organizer) side of the app.
///
/// Every `MaterialPageRoute` on the web gets a soft fade + slight upward slide
/// when it opens (and the reverse when it closes), while the page underneath
/// fades back. On phones the platform's normal transition is kept, so the
/// eventgoer app feels exactly as before.
///
/// Hooked up in `main.dart` through `ThemeData.pageTransitionsTheme`.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder({required this.fallback});

  /// Used when not running on the web.
  final PageTransitionsBuilder fallback;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!kIsWeb) {
      return fallback.buildTransitions<T>(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    // Respect the system "reduce motion" setting.
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final slide = animation
        .drive(CurveTween(curve: Curves.easeOutCubic))
        .drive(Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero));
    final fadeIn = animation.drive(
      CurveTween(curve: const Interval(0, 0.75, curve: Curves.easeOut)),
    );
    // The page being covered fades out a little earlier than the new one
    // fades in, so the two never look doubled up.
    final fadeOut = secondaryAnimation
        .drive(CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeIn)))
        .drive(Tween<double>(begin: 1, end: 0));

    return FadeTransition(
      opacity: fadeOut,
      child: FadeTransition(
        opacity: fadeIn,
        child: SlideTransition(position: slide, child: child),
      ),
    );
  }
}

/// Theme entry for `MaterialApp`: smooth on the web, platform default on
/// phones.
const PageTransitionsTheme smoothPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: SmoothPageTransitionsBuilder(
      fallback: ZoomPageTransitionsBuilder(),
    ),
    TargetPlatform.iOS: SmoothPageTransitionsBuilder(
      fallback: CupertinoPageTransitionsBuilder(),
    ),
    TargetPlatform.fuchsia: SmoothPageTransitionsBuilder(
      fallback: ZoomPageTransitionsBuilder(),
    ),
    TargetPlatform.windows: SmoothPageTransitionsBuilder(
      fallback: ZoomPageTransitionsBuilder(),
    ),
    TargetPlatform.macOS: SmoothPageTransitionsBuilder(
      fallback: CupertinoPageTransitionsBuilder(),
    ),
    TargetPlatform.linux: SmoothPageTransitionsBuilder(
      fallback: ZoomPageTransitionsBuilder(),
    ),
  },
);

/// Short cross-fade used when switching between the organizer's top-level
/// pages (Dashboard, My Events, Analytics, Escrow, Profile), so the page
/// content changes smoothly while the top bar stays put visually.
Route<T> organizerFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}
