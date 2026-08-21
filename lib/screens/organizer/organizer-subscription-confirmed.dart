import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'organizer-dashboard.dart';

class OrganizerSubscriptionConfirmedScreen extends StatelessWidget {
  final String planName;
  final String price;
  final DateTime renewsAt;

  const OrganizerSubscriptionConfirmedScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.renewsAt,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = planName == 'Premium';

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: AuthSidePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const FairTixLogo(fontSize: 24),
                  Center(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.rocket_launch_outlined,
                        size: 56,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "You're All Set!",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlock the full power of FairTix and start selling '
                        'tickets today.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _featureCheck(isPremium
                          ? 'Unlimited events & ticket capacity'
                          : 'Expanded event & ticket capacity'),
                      const SizedBox(height: 12),
                      _featureCheck('CSV export & enhanced analytics'),
                      const SizedBox(height: 12),
                      _featureCheck('Priority support'),
                    ],
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
                        decoration: const BoxDecoration(
                          color: AppColors.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Subscription Active!',
                        style: AppTextStyles.h1,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your $planName Plan features have been unlocked. '
                        'Start creating your next big event.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyGray.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('CURRENT PLAN',
                                        style: AppTextStyles.bodyGray
                                            .copyWith(fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('$planName Monthly',
                                        style: AppTextStyles.h3),
                                  ],
                                ),
                                Text(
                                  price,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                  height: 1, color: AppColors.borderLight),
                            ),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Renews ${formatFriendlyDate(renewsAt)}',
                                    style: AppTextStyles.bodyGray),
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Billing management is coming soon.'),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Manage Billing',
                                    style: TextStyle(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Go to Dashboard',
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrganizerDashboardScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Manage your subscription anytime from your Profile page.'),
                            ),
                          );
                        },
                        child: const Text(
                          'View Subscription Settings',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _featureCheck(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check, size: 18, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}