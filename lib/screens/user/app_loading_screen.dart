import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// FairTix launch splash / loading screen.
///
/// Always dark (it is the brand moment, not a themed page). It stays on screen
/// until [ready] completes — the app's real startup work — and the loading bar
/// is tied to that: it cruises toward ~88% while startup runs, then snaps to
/// 100% the moment [ready] completes, and only then calls [onFinished].
///
/// A short minimum display (the intro animation) stops a very fast startup
/// from flashing the screen for a split second. There is no fixed "wait N
/// seconds" timer deciding when loading is done.
///
/// Uses the existing local asset `assets/logo/ft_lightlogo.png`; nothing here
/// needs the network except the Plus Jakarta Sans font, which is fetched once
/// by google_fonts and cached (same font the organizer splash already uses).
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
  static const String _logoAsset = 'assets/logo/ft_lightlogo.png';

  // Colors from the spec.
  static const Color _bgTop = Color(0xFF241354);
  static const Color _bgBottom = Color(0xFF08051B);
  static const Color _taglineColor = Color(0xFFB7A5E8);
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

  TextStyle _brandStyle(double size) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    height: 1.0,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    color: Colors.white,
  );

  TextStyle _taglineStyle(double size) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    height: 1.2,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    color: _taglineColor,
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
    final logo = precacheImage(
      const AssetImage(_logoAsset),
      context,
    ).catchError((Object _) {});
    final fonts = GoogleFonts.pendingFonts([_brandStyle(36), _taglineStyle(15)])
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _bgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bgBottom,
        resizeToAvoidBottomInset: false,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
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
                    child: _branding(w),
                  ),
                  // Loading bar, bottom center, clear of the safe area.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: safeBottom + h * 0.07,
                    child: Center(child: _loadingBar(w)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _branding(double w) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(scale: _logoScale, child: _logo(w * _logoSide)),
        ),
        SizedBox(height: w * _gap),
        FadeTransition(
          opacity: _brandFade,
          child: Text(
            'FairTix',
            textAlign: TextAlign.center,
            style: _brandStyle(w * _brandFont),
          ),
        ),
        SizedBox(height: w * _gap),
        FadeTransition(
          opacity: _taglineFade,
          child: Text(
            'Discover. Book. Be There.',
            textAlign: TextAlign.center,
            style: _taglineStyle(w * _taglineFont),
          ),
        ),
      ],
    );
  }

  Widget _logo(double side) {
    return Align(
      heightFactor: _logoBand,
      alignment: const Alignment(0, _logoBandCenter),
      child: Image.asset(
        _logoAsset,
        width: side,
        height: side,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: 'FairTix',
      ),
    );
  }

  Widget _loadingBar(double w) {
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
                const Positioned.fill(child: ColoredBox(color: _track)),
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
