import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer.dart';
import '../../services/organizer_auth_service.dart';
import '../../services/organizer_session.dart';
import 'organizer-scaffold.dart';
import 'organizer-splash.dart';
import 'organizer-subscription-plan.dart';

class OrganizerProfileScreen extends StatelessWidget {
  const OrganizerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final account = OrganizerSession.instance.account;

    return OrganizerScaffold(
      pageTitle: 'Profile Settings',
      activeItem: OrganizerNavItem.profile,
      body: isWide
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Expanded(flex: 2, child: _leftColumn(context, account)),
                  const SizedBox(width: 24),
                  Expanded(flex: 3, child: _rightColumn(context, account)),
                ],
              ),
            )
          : Column(
              children: [
                _leftColumn(context, account),
                const SizedBox(height: 24),
                _rightColumn(context, account),
              ],
            ),
    );
  }

  Widget _leftColumn(BuildContext context, OrganizerAccount? account) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primaryPurpleDarker,
                child: Text(
                  account?.avatarInitial ?? '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(account?.organizationName ?? 'Organizer',
                  style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text(
                account?.email ?? '',
                style: const TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.successGreenBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified,
                        size: 15, color: AppColors.successGreen),
                    SizedBox(width: 6),
                    Text(
                      'Verified Organizer',
                      style: TextStyle(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlineButtonWidget(
          label: 'Log Out',
          borderColor: AppColors.dangerRed,
          textColor: AppColors.dangerRed,
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Log Out?'),
                content: const Text('You will need to log in again to access your organizer dashboard.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                    Navigator.pop(ctx);
                    OrganizerAuthService.instance.logout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You have been logged out.'),
                      ),
                    );
                    Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrganizerSplashScreen(),
                    ),
                      (route) => false,
                      );
                    },
                    child: const Text('Log Out',
                        style: TextStyle(color: AppColors.dangerRed)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _rightColumn(BuildContext context, OrganizerAccount? account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: 'Account Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _lockedField('Full Name', account?.fullName ?? ''),
              const SizedBox(height: 18),
              _lockedField('Email Address', account?.email ?? ''),
              const SizedBox(height: 8),
              Text(
                'These fields are locked to your verified identity documents.',
                style: AppTextStyles.bodyGray.copyWith(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Password changes are coming soon. Please contact support.'),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Change Password', style: AppTextStyles.label),
                      Icon(Icons.chevron_right,
                          color: AppColors.primaryPurple),
                    ],
                  ),
                ),
              ),
              const Divider(color: AppColors.borderLight),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Subscription Plan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account?.subscriptionPlan != null
                                ? '${account!.subscriptionPlan} Plan \u2014 Monthly'
                                : 'No active plan',
                            style: AppTextStyles.label,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            account?.subscriptionRenewsAt != null
                                ? 'Next renewal: ${formatFriendlyDate(account!.subscriptionRenewsAt!)}'
                                : 'Choose a plan to get started',
                            style: AppTextStyles.bodyGray,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: account?.subscriptionPlan != null
                            ? AppColors.successGreenBg
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                              size: 8,
                              color: account?.subscriptionPlan != null
                                  ? AppColors.successGreen
                                  : AppColors.textGray),
                          const SizedBox(width: 6),
                          Text(
                            account?.subscriptionPlan != null
                                ? 'Active'
                                : 'No Plan',
                            style: TextStyle(
                              color: account?.subscriptionPlan != null
                                  ? AppColors.successGreen
                                  : AppColors.textGray,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrganizerSubscriptionPlanScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Manage Subscription',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lockedField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: AppTextStyles.body)),
              const Icon(Icons.lock_outline, size: 18, color: AppColors.textGray),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}