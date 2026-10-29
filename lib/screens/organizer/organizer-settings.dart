import 'package:flutter/material.dart';

import '../../services/organizer_session.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_account_ui.dart';
import '../../widgets/organizer_ui.dart';
import '../../widgets/theme_mode_switch.dart';
import '../user/notifications_screen.dart';
import 'organizer-change-password.dart';
import 'organizer-scaffold.dart';

/// Organizer Settings: preferences and sign-in security only (appearance,
/// notifications, password). Who the organizer is, verification and documents
/// live on the Profile page; event settings belong to each event's Manage
/// page; plan details have their own Subscription page.
///
/// On wide screens, preferences (appearance, notifications) sit on the left and
/// sign-in security sits on the right; on narrow screens everything stacks.
///
/// Notifications: the organizer feed is always on, and there are no per-type
/// switches yet because nothing on the server reads them. Switches that do
/// nothing would be misleading, so this card only states what is delivered.
class OrganizerSettingsScreen extends StatelessWidget {
  const OrganizerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final wide = MediaQuery.of(context).size.width >= 1000;

    final preferences = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _appearanceCard(p),
        const SizedBox(height: 24),
        _notificationsCard(context, p),
      ],
    );
    final security = _securityCard(context, p);

    return OrganizerScaffold(
      pageTitle: 'Settings',
      activeItem: OrganizerNavItem.settings,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrganizerPageHeader(
            title: 'Settings',
            subtitle: 'Appearance, notifications and sign-in security.',
          ),
          const SizedBox(height: 24),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: preferences),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: security),
              ],
            )
          else ...[preferences, const SizedBox(height: 24), security],
        ],
      ),
    );
  }

  Widget _appearanceCard(FairTixPalette p) {
    return OrganizerSectionCard(
      title: 'Appearance',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.isDark ? 'Dark mode' : 'Light mode',
                  style: orgText(p, size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Switch between the light and dark look of the organizer '
                  'dashboard.',
                  style: orgText(
                    p,
                    size: 13.5,
                    color: p.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const ThemeModeSwitch(),
        ],
      ),
    );
  }

  Widget _notificationsCard(BuildContext context, FairTixPalette p) {
    return OrganizerSectionCard(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In-app notifications',
                      style: orgText(p, size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ticket sales, event status changes and announcements '
                      'appear under the bell.',
                      style: orgText(
                        p,
                        size: 13.5,
                        color: p.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const OrganizerPill(
                label: 'Always on',
                tone: OrganizerTone.accent,
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const OrganizerNote(
            text:
                'Important account updates, like your application being '
                'approved, may also reach you as a phone notification or an '
                'email. Choosing which ones you get isn\u2019t available yet.',
          ),
          const SizedBox(height: 4),
          OrganizerLinkRow(
            icon: Icons.notifications_none_rounded,
            title: 'View all notifications',
            topBorder: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityCard(BuildContext context, FairTixPalette p) {
    final account = OrganizerSession.instance.account;

    return OrganizerSectionCard(
      title: 'Sign-in & security',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                size: 18,
                color: p.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  account == null
                      ? 'Signed in'
                      : 'Signed in as ${account.email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(p, size: 14, color: p.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          OrganizerLinkRow(
            icon: Icons.lock_outline_rounded,
            title: 'Change password',
            subtitle: 'Update the password you use to sign in',
            topBorder: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OrganizerChangePasswordScreen(),
              ),
            ),
          ),
          OrganizerLinkRow(
            icon: Icons.logout_rounded,
            title: 'Log out',
            subtitle: 'Sign out of this device',
            topBorder: true,
            onTap: () => confirmOrganizerLogOut(context),
          ),
        ],
      ),
    );
  }
}
