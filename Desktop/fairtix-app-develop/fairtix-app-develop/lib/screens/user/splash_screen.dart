import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pill_button.dart';
import 'login_screen.dart';

/// First screen shown on app launch — logo, tagline, "Get Started" CTA.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 4),
              Text('FairTix', style: AppTextStyles.logo.copyWith(fontSize: 44)),
              const SizedBox(height: 12),
              Text('Fair tickets. Real fans.', style: AppTextStyles.tagline),
              const Spacer(flex: 6),
              PillButton(
                label: 'Get Started',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),
              _HomeIndicator(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.faintWhite,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
