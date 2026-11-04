import 'package:flutter/material.dart';

import '../screens/admin/admin-accounts.dart';
import '../screens/admin/admin-dashboard.dart';
import '../screens/admin/admin-events-tickets.dart';
import '../screens/admin/admin-fraud-alerts.dart';
import '../screens/admin/admin-login.dart';
import '../screens/admin/admin-organizer-applications.dart';
import '../screens/admin/admin-platform-settings.dart';
import '../screens/admin/admin-profile.dart';
import '../screens/admin/admin-resale-monitoring.dart';
import '../screens/admin/admin-revenue-reports.dart';
import '../screens/admin/admin-user-registrations.dart';
import 'notification_bell.dart';
import '../screens/admin/admin-route.dart';
import '../screens/organizer/app_colors.dart';
import '../theme/fairtix_palette.dart';
import '../theme/theme_controller.dart';
import 'top_glow_background.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_session.dart';

/// The sections in the admin sidebar, in display order.
enum AdminNavItem {
  dashboard(Icons.grid_view_rounded, 'Dashboard'),
  organizerApplications(Icons.business_outlined, 'Organizer Applications'),
  userRegistrations(Icons.how_to_reg_outlined, 'User Registrations'),
  accounts(Icons.people_outline, 'Accounts'),
  eventsTickets(Icons.calendar_today_outlined, 'Events & Tickets'),
  resaleMonitoring(Icons.swap_vert_rounded, 'Resale Monitoring'),
  fraudAlerts(Icons.shield_outlined, 'Fraud Alerts'),
  revenueReports(Icons.bar_chart_rounded, 'Revenue & Reports'),
  platformSettings(Icons.settings_outlined, 'Platform Settings'),
  profile(Icons.person_outline, 'Profile');

  const AdminNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

Widget _pageFor(AdminNavItem item) => switch (item) {
  AdminNavItem.dashboard => const AdminDashboardScreen(),
  AdminNavItem.organizerApplications =>
    const AdminOrganizerApplicationsScreen(),
  AdminNavItem.userRegistrations => const AdminUserRegistrationsScreen(),
  AdminNavItem.accounts => const AdminAccountsScreen(),
  AdminNavItem.eventsTickets => const AdminEventsTicketsScreen(),
  AdminNavItem.resaleMonitoring => const AdminResaleMonitoringScreen(),
  AdminNavItem.fraudAlerts => const AdminFraudAlertsScreen(),
  AdminNavItem.revenueReports => const AdminRevenueReportsScreen(),
  AdminNavItem.platformSettings => const AdminPlatformSettingsScreen(),
  AdminNavItem.profile => const AdminProfileScreen(),
};

Future<void> _logoutAdmin(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  AdminAuthService.instance.logout();
  adminPushAndRemoveUntil(context, const AdminLoginScreen());
}

String _adminNavLabel(AdminNavItem item) => switch (item) {
  AdminNavItem.organizerApplications => 'Applications',
  AdminNavItem.userRegistrations => 'Registrations',
  AdminNavItem.eventsTickets => 'Events',
  AdminNavItem.resaleMonitoring => 'Resale',
  AdminNavItem.fraudAlerts => 'Alerts',
  AdminNavItem.revenueReports => 'Reports',
  AdminNavItem.platformSettings => 'Settings',
  _ => item.label,
};

/// The frame every admin screen shares: a sidebar on wide windows (a drawer
/// on narrow ones), a top bar with the page [title], and a scrolling
/// [body]. Replaces the ~200 lines of sidebar / top bar / logout code that
/// each admin screen used to carry its own copy of.
///
/// Logging out here calls [AdminAuthService.logout], which also signs the
/// Supabase session out (the older per-screen copies only cleared the
/// local session).
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.active,
    required this.title,
    required this.body,
  });

  final AdminNavItem active;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final fullNav = width >= 1200;
    final palette = FairTixPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      drawer: isWide ? null : Drawer(child: _Sidebar(active: active)),
      body: Stack(
        children: [
          const TopGlowBackground(),
          Row(
            children: [
              if (isWide && !fullNav)
                SizedBox(width: 220, child: _Sidebar(active: active)),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      title: title,
                      isWide: isWide,
                      fullNav: fullNav,
                      active: active,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: width >= 1200 ? 32 : (isWide ? 20 : 14),
                          vertical: width >= 1200 ? 28 : 18,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1900),
                            child: body,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.isWide,
    required this.fullNav,
    required this.active,
  });

  final String title;
  final bool isWide;
  final bool fullNav;
  final AdminNavItem active;

  @override
  Widget build(BuildContext context) {
    final email = AdminSession.instance.currentEmail ?? 'admin';
    final palette = FairTixPalette.of(context);
    return Container(
      height: fullNav ? 88 : 64,
      padding: EdgeInsets.symmetric(horizontal: fullNav ? 32 : 18),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: palette.accentLabel),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const _AdminLogo(),
          if (fullNav) ...[
            const SizedBox(width: 28),
            Expanded(child: _AdminNavPill(active: active)),
            const SizedBox(width: 28),
          ] else ...[
            const Spacer(),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
          ],
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surface,
              border: Border.all(color: palette.border),
            ),
            alignment: Alignment.center,
            child: NotificationBell(
              size: 20,
              color: palette.accentLabel,
              badgeBorderColor: palette.surface,
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'profile') {
                adminPushReplacement(context, const AdminProfileScreen());
              } else if (value == 'theme') {
                ThemeController.instance.toggle();
              } else {
                _logoutAdmin(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      palette.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(palette.isDark ? 'Light mode' : 'Dark mode'),
                  ],
                ),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
            child: _AdminAvatar(email: email, color: palette.primary),
          ),
        ],
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({required this.email, required this.color});

  final String email;
  final Color color;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 22,
    backgroundColor: color,
    child: Text(
      email.isEmpty ? 'A' : email[0].toUpperCase(),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

class _AdminNavPill extends StatelessWidget {
  const _AdminNavPill({required this.active});

  final AdminNavItem active;

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final item in AdminNavItem.values.where(
            (item) => item != AdminNavItem.profile,
          ))
            Flexible(
              child: _SidebarItem(
                icon: item.icon,
                label: _adminNavLabel(item),
                selected: item == active,
                horizontal: true,
                onTap: () {
                  if (item != active) {
                    adminPushReplacement(context, _pageFor(item));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.active});

  final AdminNavItem active;

  Future<void> _logout(BuildContext context) async {
    await _logoutAdmin(context);
  }

  @override
  Widget build(BuildContext context) {
    final email = AdminSession.instance.currentEmail ?? 'admin';
    final palette = FairTixPalette.of(context);
    return Container(
      color: palette.surface.withValues(alpha: 0.78),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 12, 18),
              child: _AdminLogo(),
            ),
            Divider(height: 1, color: palette.border),
            const SizedBox(height: 14),
            // Scrolls on short screens (landscape phones, small windows) so the
            // list can never overflow; the account footer stays pinned below.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final item in AdminNavItem.values)
                      _SidebarItem(
                        icon: item.icon,
                        label: item.label,
                        selected: item == active,
                        onTap: () {
                          if (item == active) return;
                          adminPushReplacement(context, _pageFor(item));
                        },
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: palette.progressTrack,
                    child: Icon(
                      Icons.person,
                      size: 17,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: AppTextStyles.label.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _logout(context),
                    icon: Icon(
                      Icons.logout,
                      size: 17,
                      color: palette.textSecondary,
                    ),
                    tooltip: 'Log out',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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

class _AdminLogo extends StatelessWidget {
  const _AdminLogo();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FairTixPalette.of(context).primary,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(
          Icons.confirmation_number_outlined,
          color: Colors.white,
          size: 14,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        'FairTix',
        style: TextStyle(
          color: FairTixPalette.of(context).textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
        ),
      ),
      const SizedBox(width: 3),
      Text(
        'ADMIN',
        style: TextStyle(
          fontSize: 8,
          color: FairTixPalette.of(context).textSecondary,
        ),
      ),
    ],
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal ? 2 : 10,
        vertical: horizontal ? 0 : 3,
      ),
      child: Material(
        color: selected ? palette.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(horizontal ? 999 : 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(horizontal ? 999 : 12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal ? 10 : 12,
              vertical: horizontal ? 12 : 11,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : palette.textSecondary,
                ),
                SizedBox(width: horizontal ? 6 : 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : palette.textSecondary,
                      fontSize: horizontal ? 11 : 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
