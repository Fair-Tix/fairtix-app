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
import '../screens/admin/admin-route.dart';
import '../screens/organizer/app_colors.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_session.dart';

/// The sections in the admin sidebar, in display order.
enum AdminNavItem {
  dashboard(Icons.grid_view_rounded, 'Dashboard'),
  organizerApplications(Icons.business_outlined, 'Organizer Applications'),
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
  AdminNavItem.organizerApplications => const AdminOrganizerApplicationsScreen(),
  AdminNavItem.accounts => const AdminAccountsScreen(),
  AdminNavItem.eventsTickets => const AdminEventsTicketsScreen(),
  AdminNavItem.resaleMonitoring => const AdminResaleMonitoringScreen(),
  AdminNavItem.fraudAlerts => const AdminFraudAlertsScreen(),
  AdminNavItem.revenueReports => const AdminRevenueReportsScreen(),
  AdminNavItem.platformSettings => const AdminPlatformSettingsScreen(),
  AdminNavItem.profile => const AdminProfileScreen(),
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
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      drawer: isWide ? null : Drawer(child: _Sidebar(active: active)),
      body: Row(
        children: [
          if (isWide) SizedBox(width: 180, child: _Sidebar(active: active)),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: title, isWide: isWide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWide ? 18 : 14),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.isWide});

  final String title;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final email = AdminSession.instance.currentEmail ?? 'admin';
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, size: 20),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Text(title, style: AppTextStyles.label),
          const Spacer(),
          const Icon(Icons.notifications_none, size: 19, color: AppColors.textGray),
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFE8E6F1),
            child: Icon(Icons.person, size: 16, color: AppColors.textGray),
          ),
          if (isWide) ...[
            const SizedBox(width: 8),
            Text(email, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.active});

  final AdminNavItem active;

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to Log Out?'),
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
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AdminSession.instance.currentEmail ?? 'admin';
    return Container(
      color: const Color(0xFFF3F1FD),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 12, 18),
              child: _AdminLogo(),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 14),
            for (final item in AdminNavItem.values)
              _SidebarItem(
                icon: item.icon,
                label: item.label,
                selected: item == active,
                onTap: () {
                  if (item == active) return;
                  Navigator.pushReplacement(context, adminPageRoute(_pageFor(item)));
                },
              ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 15,
                    backgroundColor: Color(0xFFE8E6F1),
                    child: Icon(Icons.person, size: 17, color: AppColors.textGray),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin', style: AppTextStyles.label),
                        Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textGray, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, size: 17, color: AppColors.textGray),
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
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 14),
      ),
      const SizedBox(width: 6),
      const Text(
        'FairTix',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic),
      ),
      const SizedBox(width: 3),
      const Text('ADMIN', style: TextStyle(fontSize: 8, color: AppColors.textGray)),
    ],
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: Material(
      color: selected ? AppColors.primaryPurple : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textDark),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textDark,
                    fontSize: 10,
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
