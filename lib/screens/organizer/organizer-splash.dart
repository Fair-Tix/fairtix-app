import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/fairtix_palette.dart';
import '../../widgets/fairtix_mark.dart';
import '../../widgets/theme_mode_switch.dart';
import '../../widgets/top_glow_background.dart';
import 'organizer-public-landing.dart';

/// Organizer splash (Mahilum design): logo, wordmark, "FOR ORGANIZERS" and a
/// progress bar. When the bar fills, it fades into the public landing page.
///
/// Sizes and gaps are measured from the design (1440x800 frame):
/// logo 225 wide, wordmark 36px, tagline 12px / +0.18em, bar 220x6.
class OrganizerSplashScreen extends StatefulWidget {
  const OrganizerSplashScreen({super.key});

  @override
  State<OrganizerSplashScreen> createState() => _OrganizerSplashScreenState();
}

/// Centers [child] and animates it: it eases in (fade + gentle scale up) when
/// the splash opens, and eases out (fade + slight zoom) just before the landing
/// page takes over.
class _MotionCenter extends StatelessWidget {
  const _MotionCenter({
    required this.intro,
    required this.exit,
    required this.child,
  });

  final Animation<double> intro;
  final Animation<double> exit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([intro, exit]),
        child: child,
        builder: (context, child) {
          final inV = Curves.easeOutCubic.transform(intro.value);
          final outV = Curves.easeInCubic.transform(exit.value);
          return Opacity(
            opacity: (inV * (1 - outV)).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: (0.94 + 0.06 * inV) * (1 + 0.05 * outV),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _OrganizerSplashScreenState extends State<OrganizerSplashScreen>
    with TickerProviderStateMixin {
  static const Duration _loadDuration = Duration(milliseconds: 2400);
  static const double _barWidth = 220;
  static const double _barHeight = 6;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _loadDuration,
  );

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _progress.forward().whenComplete(_exitThenLand);
  }

  @override
  void dispose() {
    _progress.dispose();
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  Future<void> _exitThenLand() async {
    if (!mounted) return;
    await _exit.forward();
    _goToLanding();
  }

  void _goToLanding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, _, _) => const OrganizerPublicLandingScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = animation.drive(
            CurveTween(curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: curved.drive(
                Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          const TopGlowBackground(),

          _MotionCenter(
            intro: _intro,
            exit: _exit,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FairTixMark(width: 225),
                const SizedBox(height: 17.6),
                Text(
                  'FairTix',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 36,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  'FOR ORGANIZERS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: p.accentLabel,
                  ),
                ),
                const SizedBox(height: 35),
                Semantics(
                  label: 'Loading',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_barHeight),
                    child: SizedBox(
                      width: _barWidth,
                      height: _barHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(child: ColoredBox(color: p.progressTrack)),
                          AnimatedBuilder(
                            animation: _progress,
                            builder: (context, _) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor:
                                  Curves.easeInOut.transform(_progress.value),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: p.primary,
                                  borderRadius:
                                      BorderRadius.circular(_barHeight),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Light / Dark switch, top-right.
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ThemeModeSwitch(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
