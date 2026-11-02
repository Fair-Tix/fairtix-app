import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_dark_ui.dart' show FtLogo, FtText;
import '../../widgets/ft_profile_ui.dart' show ftOverlayStyle;

/// FairTix launch splash / loading screen.
///
/// Dark by default; follows the Light / Dark choice saved from Settings >
/// Appearance (main() loads it before the first frame, so there is no flash of
/// the wrong mode). Dark uses `assets/logo/ft_lightlogo.png`, Light uses
/// `assets/logo/ft_darklogo.png` (the purple logo for light backgrounds).
///
/// It stays on screen until [ready] completes — the app's real startup work —
/// and the loading bar is tied to that: it cruises toward ~88% while startup
/// runs, then snaps to 100% the moment [ready] completes, and only then calls
/// [onFinished].
///
/// A short minimum display (the intro animation) stops a very fast startup
/// from flashing the screen for a split second. There is no fixed "wait N
/// seconds" timer deciding when loading is done.
///
/// Nothing here needs the network except the Plus Jakarta Sans font, which is
/// fetched once by google_fonts and cached (same font the organizer splash
/// already uses).
class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({
    super.key,
    required this.ready,
    required this.onFinished,
  });

  /// Completes when app initialization is done. Errors are treated as "done"
  /// so the splash can never get stuck.
  final Future<void> ready;

  /// Called once, after the bar has filled. The parent swaps in the real app.
  final VoidCallback onFinished;

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen>
    with TickerProviderStateMixin {
  // Dark-mode bar track from the original spec (Light uses the palette's).
  static const Color _track = Color(0xFF302064);
  static const Color _fillStart = Color(0xFF8138ED);
  static const Color _fillEnd = Color(0xFFC69AFF);

  // Layout, as fractions of the (phone-width) screen, measured from the
  // reference image (421 px wide).
  static const double _maxPhoneWidth = 560;
  static const double _logoSide = 0.637; // image box; the ticket is ~69% of it
  static const double _brandFont = 0.083;
  static const double _taglineFont = 0.0355;
  static const double _gap = 0.055;
  static const double _barWidth = 0.23;
  static const double _barHeight = 9;

  // The PNG is a square with transparent padding around the ticket. Layout
  // only keeps the middle band that holds the ticket (nothing is cropped or
  // scaled), so the brand name sits the right distance below it.
  static const double _logoBand = 0.5;
  static const double _logoBandCenter = -0.06;

  static const double _cruiseTo = 0.88;
  static const Duration _fontWait = Duration(milliseconds: 800);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _progress = AnimationController(vsync: this);

  late final Animation<double> _logoFade = _intro.drive(
    CurveTween(curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _logoScale = _logoFade.drive(
    Tween<double>(begin: 0.92, end: 1.0),
  );
  late final Animation<double> _brandFade = _intro.drive(
    CurveTween(curve: const Interval(0.25, 0.70, curve: Curves.easeOut)),
  );
  late final Animation<double> _taglineFade = _intro.drive(
    CurveTween(curve: const Interval(0.45, 0.90, curve: Curves.easeOut)),
  );

  bool _started = false;

  TextStyle _brandStyle(double size, [Color color = Colors.white]) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        color: color,
      );

  TextStyle _taglineStyle(double size, [Color color = const Color(0xFFB7A5E8)]) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: color,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  @override
  void dispose() {
    _intro.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    // Warm the logo and fonts first so nothing pops in or swaps font while the
    // fade-in plays. The logo is a local asset (near-instant); the font wait
    // is capped so a first offline launch is never held up.
    // (The palette is read before the first await, while the context is
    // still safe to depend on.)
    final isDark = FairTixPalette.of(context).isDark;
    final logo = precacheImage(
      AssetImage(isDark ? FtLogo.asset : FtLogo.darkAsset),
      context,
    ).catchError((Object _) {});
    final fonts = GoogleFonts.pendingFonts([
          _brandStyle(36),
          _taglineStyle(15),
          // Login-screen fonts too, so the next screen doesn't swap fonts.
          ...FtText.warmUpStyles(),
        ])
        .timeout(_fontWait, onTimeout: () => <void>[])
        .then<void>((_) {}, onError: (Object _) {});
    await Future.wait<void>([logo, fonts]);
    if (!mounted) return;

    final intro = _intro.forward();
    unawaited(
      _progress.animateTo(
        _cruiseTo,
        duration: const Duration(milliseconds: 2800),
        curve: Curves.easeOutCubic,
      ),
    );

    // Done = real startup finished AND the intro had time to play.
    await Future.wait<void>([
      widget.ready.then<void>((_) {}, onError: (Object _) {}),
      intro,
    ]);
    if (!mounted) return;

    await _progress.animateTo(
      1.0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ftOverlayStyle(p),
      child: Scaffold(
        backgroundColor: p.gradientBottom,
        resizeToAvoidBottomInset: false,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Light fades out sooner, like the reference; Dark is unchanged.
              stops: p.isDark ? null : const [0.0, 0.5],
              colors: [p.gradientTop, p.gradientBottom],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = math.min(constraints.maxWidth, _maxPhoneWidth);
              final h = constraints.maxHeight;
              final safeBottom = MediaQuery.paddingOf(context).bottom;

              return Stack(
                children: [
                  // Branding group, a little above the vertical midpoint.
                  Align(
                    alignment: const Alignment(0, -0.16),
                    child: _branding(w, p),
                  ),
                  // Loading bar, bottom center, clear of the safe area.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: safeBottom + h * 0.07,
                    child: Center(child: _loadingBar(w, p)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _branding(double w, FairTixPalette p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: _logo(w * _logoSide, p.isDark ? FtLogo.asset : FtLogo.darkAsset),
          ),
        ),
        SizedBox(height: w * _gap),
        FadeTransition(
          opacity: _brandFade,
          child: Text(
            'FairTix',
            textAlign: TextAlign.center,
            style: _brandStyle(w * _brandFont, p.textStrong),
          ),
        ),
        SizedBox(height: w * _gap),
        FadeTransition(
          opacity: _taglineFade,
          child: Text(
            'Discover. Book. Be There.',
            textAlign: TextAlign.center,
            style: _taglineStyle(w * _taglineFont, p.textSoft),
          ),
        ),
      ],
    );
  }

  Widget _logo(double side, String asset) {
    return Align(
      heightFactor: _logoBand,
      alignment: const Alignment(0, _logoBandCenter),
      child: Image.asset(
        asset,
        width: side,
        height: side,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: 'FairTix',
      ),
    );
  }

  Widget _loadingBar(double w, FairTixPalette p) {
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: SizedBox(
          width: w * _barWidth,
          height: _barHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_barHeight),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: p.isDark ? _track : p.progressTrack),
                ),
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progress.value.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_barHeight),
                        gradient: const LinearGradient(
                          colors: [_fillStart, _fillEnd],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
