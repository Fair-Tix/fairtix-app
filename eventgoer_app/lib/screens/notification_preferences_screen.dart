import 'package:flutter/material.dart';

import '../models/notification_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/purple_header_bar.dart';

/// "Notification Preferences" screen — lets the user choose which
/// channels (push/email) and which optional notification types
/// (resale activity, promotions) they want to receive. Transactional
/// notifications (ticket/purchase, cancellations/refunds) always stay
/// on and are shown as locked.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = notificationSettings;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Notification Preferences',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: 'Channels',
              children: [
                _ToggleRow(
                  icon: Icons.notifications_active_rounded,
                  label: 'Push Notifications',
                  subtitle: 'Alerts sent to this device',
                  value: settings.pushEnabled,
                  onChanged: (v) => setState(() => settings.pushEnabled = v),
                ),
                const Divider(color: AppColors.inputBorderLight, height: 28),
                _ToggleRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email Notifications',
                  subtitle: 'Alerts sent to your registered email',
                  value: settings.emailEnabled,
                  onChanged: (v) => setState(() => settings.emailEnabled = v),
                ),
                const Divider(color: AppColors.inputBorderLight, height: 28),
                const _LockedRow(
                  icon: Icons.smartphone_rounded,
                  label: 'In-App Notifications',
                  subtitle: 'Always on \u2014 shown in your Notifications feed',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Notification Types',
              children: [
                const _LockedRow(
                  icon: Icons.confirmation_number_rounded,
                  label: 'Ticket & Purchase Updates',
                  subtitle: 'Purchase confirmations and QR code updates. Always on.',
                ),
                const Divider(color: AppColors.inputBorderLight, height: 28),
                const _LockedRow(
                  icon: Icons.event_busy_rounded,
                  label: 'Event Cancellations & Refunds',
                  subtitle: 'Time-sensitive refund notices. Always on.',
                ),
                const Divider(color: AppColors.inputBorderLight, height: 28),
                _ToggleRow(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Resale Activity',
                  subtitle: 'Listing created, ticket sold, resale completed',
                  value: settings.resaleActivityEnabled,
                  onChanged: (v) => setState(() => settings.resaleActivityEnabled = v),
                ),
                const Divider(color: AppColors.inputBorderLight, height: 28),
                _ToggleRow(
                  icon: Icons.campaign_rounded,
                  label: 'Promotional Announcements',
                  subtitle: 'New event alerts from organizers you\u2019ve bought from',
                  value: settings.promoEnabled,
                  onChanged: (v) => setState(() => settings.promoEnabled = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputFillLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.accentPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Security and transaction alerts can\u2019t be turned off, to make sure you never miss a refund or entry update.',
                      style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.accentPurple),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.accentPurple,
        ),
      ],
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.icon, required this.label, required this.subtitle});

  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(width: 6),
                  const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: true,
          onChanged: null,
        ),
      ],
    );
  }
}
