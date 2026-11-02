import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../navigation/main_shell.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_otp_field.dart';
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import '../../widgets/ft_verified_ui.dart';

/// Shown once an eventgoer's account has been reviewed and approved
/// ("You're verified").
///
/// Dark redesign. The button runs the same navigation the old "Go to Home"
/// button did (back to the main shell, clearing the stack); only the
/// presentation was replaced. The details below are no longer displayed, so
/// they are optional now, but they stay in the constructor so any existing
/// caller keeps compiling.
///
/// TODO(backend): populate these from the real user record if a future design
/// needs them.
class AccountActivatedScreen extends StatefulWidget {
  const AccountActivatedScreen({
    super.key,
    this.fullName = '',
    this.idType = '',
    this.email = '',
    this.memberSince,
    this.accountType = 'Buyer',
  });

  final String fullName;
  final String idType;
  final String email;
  final String accountType;
  final DateTime? memberSince;

  @override
  State<AccountActivatedScreen> createState() => _AccountActivatedScreenState();
}

class _AccountActivatedScreenState extends State<AccountActivatedScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = 1500;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _browseEvents() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    final p = FairTixPalette.of(context);
    // Dark keeps the original verified colors; Light uses the palette's.
    final Color? verifiedBg = t.isDark ? null : p.verifiedSurface;
    final Color? verifiedFg = t.isDark ? null : p.verified;

    // Screen fade (0-450 ms), then circle, check, heading, badge, message
    // and button, each ~130 ms after the previous one.
    final screenFade = _entrance.drive(
      CurveTween(curve: Interval(0, 450 / _totalMs, curve: Curves.easeOut)),
    );
    final draw = _entrance.drive(
      CurveTween(
        curve: Interval(550 / _totalMs, 1100 / _totalMs, curve: Curves.easeInOut),
      ),
    );

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.overlayStyle,
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: FadeTransition(
          opacity: screenFade,
          child: FtAuthBackground(
            theme: t,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FtReveal(
                                  animation: _entrance,
                                  startMs: 100,
                                  endMs: 550,
                                  totalMs: _totalMs,
                                  scaleFrom: 0.7,
                                  child: FtVerifiedCircle(
                                    draw: draw,
                                    background: verifiedBg,
                                    checkColor: verifiedFg,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                FtReveal(
                                  animation: _entrance,
                                  startMs: 650,
                                  endMs: 1100,
                                  totalMs: _totalMs,
                                  slide: 12,
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      'You’re verified',
                                      textAlign: TextAlign.center,
                                      style: FtText.title().copyWith(
                                        color: t.titleColor,
                                        fontSize: 32,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FtReveal(
                                  animation: _entrance,
                                  startMs: 780,
                                  endMs: 1230,
                                  totalMs: _totalMs,
                                  slide: 8,
                                  child: FtVerifiedBadge(
                                    background: verifiedBg,
                                    foreground: verifiedFg,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FtReveal(
                                  animation: _entrance,
                                  startMs: 910,
                                  endMs: 1360,
                                  totalMs: _totalMs,
                                  slide: 8,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 300),
                                    child: Text(
                                      'You can now buy tickets and resell them safely.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        height: 1.45,
                                        fontWeight: FontWeight.w400,
                                        color: t.secondaryText,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  FtReveal(
                    animation: _entrance,
                    startMs: 1040,
                    endMs: 1500,
                    totalMs: _totalMs,
                    slide: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.bgBottom,
                        border: Border(top: BorderSide(color: t.surfaceBorder)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                        child: FtVerifyButton(
                          label: 'Browse Events',
                          onPressed: _browseEvents,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
