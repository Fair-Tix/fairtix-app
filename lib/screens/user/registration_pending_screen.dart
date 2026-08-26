import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/timeline_step.dart';
import 'account_activated_screen.dart';

class RegistrationPendingScreen extends StatelessWidget {
  const RegistrationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              const SizedBox(height: 12),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: AppColors.gradientBottom, size: 30),
              ),
              const SizedBox(height: 20),
              Text('Verification Pending', style: AppTextStyles.heading, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text(
                'Your ID is currently being reviewed. This usually takes 1-2 business days.',
                textAlign: TextAlign.center,
                style: AppTextStyles.tagline,
              ),
              const SizedBox(height: 28),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TimelineStep(
                    title: 'ID Submitted',
                    statusLabel: 'Completed',
                    status: TimelineStepStatus.completed,
                  ),
                  TimelineStep(
                    title: 'Under Review',
                    statusLabel: 'In Progress',
                    status: TimelineStepStatus.inProgress,
                  ),
                  TimelineStep(
                    title: 'Account Activated',
                    statusLabel: 'Waiting',
                    status: TimelineStepStatus.waiting,
                    showConnector: false,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SUBMITTED ID DETAILS', style: AppTextStyles.cardLabel),
                    const SizedBox(height: 14),
                    _detailRow('ID Type', 'Philippine National ID (PhilSys)'),
                    const SizedBox(height: 10),
                    _detailRow('Submitted', 'June 27, 2026 • 9:41 AM'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status', style: AppTextStyles.bodyMuted),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Pending Review',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You will be notified via email and in-app once your account has been activated.',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PillButton(
                label: 'Back to Home',
                onPressed: () {
                  // TODO: this button currently simulates admin approval by
                  // jumping to Account Activated, for UI preview purposes only.
                  // Once backend review status is wired up, this should just
                  // go back Home, and Account Activated should instead be
                  // reached via a push notification / in-app alert once the
                  // account is actually approved.
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AccountActivatedScreen()),
                  );
                },
              ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMuted),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}
