import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/step_dots.dart';
import 'registration_pending_screen.dart';

class SelfieVerificationScreen extends StatefulWidget {
  const SelfieVerificationScreen({super.key});

  @override
  State<SelfieVerificationScreen> createState() => _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen> {
  bool _isSubmitting = false;

  Future<void> _handleTakeSelfie() async {
    // TODO: hook up camera capture + face-embedding comparison via Cloud Functions.
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegistrationPendingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Verify Your Identity',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const StepDots(
              totalSteps: 3,
              currentStep: 2,
              activeColor: AppColors.white,
              inactiveColor: AppColors.faintWhite,
            ),
            const Spacer(flex: 2),
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 3),
              ),
              child: const Padding(
                padding: EdgeInsets.all(30),
                child: Icon(Icons.person_outline, size: 130, color: AppColors.faintWhite),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Position your face within the frame', style: AppTextStyles.tagline),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  GradientPillButton(
                    label: 'Take Selfie',
                    loading: _isSubmitting,
                    onPressed: _handleTakeSelfie,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This will be compared with your uploaded ID.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.footerText,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
