import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/ft_dark_ui.dart';
import 'login_screen.dart';

/// Welcome screen: logo, tagline and a "Get Started" button.
///
/// Uses the same background, logo and button as the login screen, and follows
/// the Light / Dark switch (purple logo on the light background, white logo on
/// the dark one).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    const Spacer(flex: 4),
                    FtLogo(ticketWidth: 110, dark: !t.isDark),
                    const SizedBox(height: 22),
                    Text(
                      'FairTix',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 44,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: t.titleColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fair tickets. Real fans.',
                      textAlign: TextAlign.center,
                      style: t.subtitle().copyWith(fontSize: 15),
                    ),
                    const Spacer(flex: 6),
                    FtGradientButton(
                      label: 'Get Started',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
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
