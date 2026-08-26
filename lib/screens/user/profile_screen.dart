import 'package:flutter/material.dart';

import '../../data/sample_user.dart';
import '../../theme/app_theme.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'notification_preferences_screen.dart';
import 'simple_placeholder_screen.dart';
import 'transactions_screen.dart';

/// "My Profile" tab — account details, ID verification status, app
/// settings, and log out.
/// TODO: replace `currentUser` with the real signed-in user from
/// Firebase Auth once the backend is wired up.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _handleLogOut(BuildContext context) {
    // TODO: sign out of Firebase Auth here once wired up.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openPlaceholder(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SimplePlaceholderScreen(title: title, icon: icon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('My Profile', style: AppTextStyles.sectionHeading),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1526),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accentPurple, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          user.initials,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(user.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text(user.username, style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 12),
                    if (user.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
                            SizedBox(width: 6),
                            Text('FairTix Verified', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Account Details
                    _SectionCard(
                      title: 'Account Details',
                      children: [
                        _LockedField(label: 'FULL NAME', value: user.fullName),
                        const Divider(color: AppColors.inputBorderLight, height: 28),
                        _LockedField(label: 'EMAIL ADDRESS', value: user.email),
                        const SizedBox(height: 4),
                        Text(
                          'These fields are locked to your verified ID and cannot be changed.',
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                        const Divider(color: AppColors.inputBorderLight, height: 28),
                        _IconNavRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'CHANGE PASSWORD',
                          value: 'Change Password',
                          onTap: () => _openPlaceholder(context, 'Change Password', Icons.lock_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ID Verification
                    _SectionCard(
                      title: 'ID Verification',
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 18, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user.idType,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 12, color: AppColors.white),
                              SizedBox(width: 4),
                              Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your government/school ID has been verified.',
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Payments
                    _SectionCard(
                      title: 'Payments',
                      children: [
                        _IconNavRow(
                          icon: Icons.receipt_long_rounded,
                          label: 'TRANSACTIONS',
                          value: 'View Transactions',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // App Settings
                    _SectionCard(
                      title: 'App Settings',
                      children: [
                        _IconNavRow(
                          icon: Icons.notifications_none_rounded,
                          label: 'NOTIFICATION PREFERENCES',
                          value: 'Notification Preferences',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()),
                          ),
                        ),
                        const Divider(color: AppColors.inputBorderLight, height: 28),
                        _IconNavRow(
                          icon: Icons.help_outline_rounded,
                          label: 'HELP & SUPPORT',
                          value: 'Help & Support',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => _handleLogOut(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
        ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.cardLabel),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ],
          ),
        ),
        const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
      ],
    );
  }
}

class _IconNavRow extends StatelessWidget {
  const _IconNavRow({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accentPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.cardLabel),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
        ],
      ),
    );
  }
}
