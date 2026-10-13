import 'package:flutter/material.dart';

import '../../navigation/main_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pill_button.dart';

/// Shown once an eventgoer's account has been reviewed and approved.
/// TODO(backend): this should be reached via a push notification / in-app
/// alert triggered when an admin actually approves the account (see
/// RegistrationPendingScreen), with [fullName]/[idType]/[email] populated
/// from the real Firestore user record and [memberSince] set to the
/// account's real creation date — not left to the defaults below.
class AccountActivatedScreen extends StatelessWidget {
  const AccountActivatedScreen({
    super.key,
    required this.fullName,
    required this.idType,
    required this.email,
    required this.memberSince,
    this.accountType = 'Buyer',
  });

  final String fullName;
  final String idType;
  final String email;
  final String accountType;
  final DateTime memberSince;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatMemberSince(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

  @override
  Widget build(BuildContext context) {
    final firstName = fullName.trim().isEmpty ? 'there' : fullName.trim().split(RegExp(r'\s+')).first;
    return Scaffold(
      body: GradientBackground(
        gradient: AppGradients.confirmation,
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
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: AppColors.white.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.accentPurple, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Account Activated!', style: AppTextStyles.heading, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Your identity has been verified. Welcome to\nFairTix, $firstName!',
                textAlign: TextAlign.center,
                style: AppTextStyles.tagline,
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VERIFICATION STATUS', style: AppTextStyles.fieldLabel),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                              SizedBox(width: 4),
                              Icon(Icons.check_circle, size: 14, color: AppColors.success),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: AppColors.fieldBorder, height: 1),
                    ),
                    _row('Full Name', fullName),
                    const SizedBox(height: 12),
                    _row('ID Type', idType),
                    const SizedBox(height: 12),
                    _row('Email', email),
                    const SizedBox(height: 12),
                    _row('Account Type', accountType, valueColor: AppColors.white),
                    const SizedBox(height: 12),
                    _row('Member Since', _formatMemberSince(memberSince)),
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
                    Icon(Icons.lock_open_rounded, color: AppColors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You can now browse events, purchase tickets, and access the Resale Market.',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              PillButton(
                label: 'Go to Home',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 3)),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.white, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text(
                    'View My Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
                  ),
                ),
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

  Widget _row(String label, String value, {Color valueColor = AppColors.white}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: valueColor),
          ),
        ),
      ],
    );
  }
}
