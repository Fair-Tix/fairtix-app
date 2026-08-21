import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'organizer-splash.dart';
import 'organizer-verification-pending.dart';

class OrganizerApplicationSubmittedScreen extends StatelessWidget {
  const OrganizerApplicationSubmittedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (isWide)
            Expanded(
              flex: 5,
              child: AuthSidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FairTixLogo(fontSize: 22),
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Almost There!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your application is under review. We\'ll notify you '
                      'within 2-3 business days.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.description_outlined,
                          color: AppColors.primaryPurple,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Application Submitted',
                        style: AppTextStyles.h1,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We\'ve received your application to become a FairTix '
                        'organizer. Our team will review your documents to '
                        'ensure the safety of our community.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyGray.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _infoRow('Est. Review Time', '2-3 Business Days'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                  height: 1, color: AppColors.borderLight),
                            ),
                            _infoRow('Status', 'Pending Verification',
                                valueColor: AppColors.warningOrange),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Go to Home',
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrganizerSplashScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlineButtonWidget(
                        label: 'Check Verification Status',
                        textColor: AppColors.textDark,
                        borderColor: AppColors.borderLight,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const OrganizerVerificationPendingScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyGray),
        Text(
          value,
          style: AppTextStyles.label.copyWith(
            color: valueColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }
}