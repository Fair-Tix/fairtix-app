import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/timeline_step.dart';
import 'login_screen.dart';

class RegistrationPendingScreen extends StatelessWidget {
  const RegistrationPendingScreen({
    super.key,
    this.idType = '',
    this.submittedAt,
  });

  final String idType;
  final DateTime? submittedAt;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatSubmittedAt(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_months[dt.month - 1]} ${dt.day}, ${dt.year} \u2022 $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final displayIdType = idType.isNotEmpty ? idType : 'Not specified';
    final displaySubmittedAt = submittedAt != null ? _formatSubmittedAt(submittedAt!) : 'Just now';
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
                    _detailRow('ID Type', displayIdType),
                    const SizedBox(height: 10),
                    _detailRow('Submitted', displaySubmittedAt),
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
                  // TODO(backend): once account review status is wired up,
                  // AccountActivatedScreen should be reached via a push
                  // notification / in-app alert when the account is
                  // actually approved by an admin — not from this button.
                  // This button genuinely just returns to the login screen,
                  // matching its label.
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
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
