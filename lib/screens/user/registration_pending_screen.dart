import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../navigation/main_shell.dart';
import '../../services/user_auth_service.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_otp_field.dart';
import '../../widgets/ft_pending_ui.dart';

/// Registration, Step 5 of 5: ID under review.
///
/// Dark redesign. The "Proceed to Dashboard" action is the same code the
/// old "Back to Home" button ran; only the presentation was replaced.
class RegistrationPendingScreen extends StatefulWidget {
  const RegistrationPendingScreen({
    super.key,
    this.idType = '',
    this.submittedAt,
  });

  // Still passed in by the selfie step; kept so that call site is untouched.
  final String idType;
  final DateTime? submittedAt;

  @override
  State<RegistrationPendingScreen> createState() =>
      _RegistrationPendingScreenState();
}

class _RegistrationPendingScreenState extends State<RegistrationPendingScreen>
    with TickerProviderStateMixin {
  static const int _totalMs = 1100;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: show everything immediately, nothing loops.
      _entrance.value = 1;
    } else {
      _entrance.forward();
      _pulse.repeat(reverse: true);
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _proceedToDashboard() async {
    // The eventgoer is already signed in (the email OTP created
    // their session), so go Home. Load their profile first so
    // the app knows their approval status. Browsing works right
    // away; buying and reselling stay locked until an admin
    // approves the account.
    await UserAuthService.instance.refreshAccount();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.overlayStyle,
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: FtAuthBackground(
          theme: t,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(21, 56, 21, 24),
                    child: Column(
                      children: [
                        FtReveal(
                          animation: _entrance,
                          startMs: 0,
                          endMs: 400,
                          totalMs: _totalMs,
                          scaleFrom: 0.85,
                          child: FtPendingClock(pulse: _pulse),
                        ),
                        const SizedBox(height: 26),
                        FtReveal(
                          animation: _entrance,
                          startMs: 200,
                          endMs: 550,
                          totalMs: _totalMs,
                          slide: 14,
                          child: Semantics(
                            header: true,
                            child: Text(
                              'ID under review',
                              textAlign: TextAlign.center,
                              style: FtText.title().copyWith(
                                color: t.titleColor,
                                fontSize: 29,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FtReveal(
                          animation: _entrance,
                          startMs: 350,
                          endMs: 650,
                          totalMs: _totalMs,
                          slide: 10,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 310),
                            child: Text(
                              'We’ll email you as soon as your account is ready.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                height: 23 / 15.5,
                                fontWeight: FontWeight.w400,
                                color: t.secondaryText,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        FtReveal(
                          animation: _entrance,
                          startMs: 450,
                          endMs: 850,
                          totalMs: _totalMs,
                          slide: 24,
                          child: FtVerificationCard(
                            entrance: _entrance,
                            totalMs: _totalMs,
                            spin: _spin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FtReveal(
                  animation: _entrance,
                  startMs: 600,
                  endMs: 900,
                  totalMs: _totalMs,
                  slide: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.bgBottom,
                      border: Border(top: BorderSide(color: t.surfaceBorder)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(21, 16, 21, 14),
                      child: FtVerifyButton(
                        label: 'Proceed to Dashboard',
                        onPressed: _proceedToDashboard,
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
    );
  }
}
