import 'package:flutter/material.dart';

import '../../services/admin_session.dart';
import '../organizer/app_colors.dart';
import 'admin-announcement.dart';
import 'admin-accounts.dart';
import 'admin-login.dart';
import 'admin-organizer-applications.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-route.dart';
import 'admin-resale-monitoring.dart';
import 'admin-revenue-reports.dart';
import 'admin-platform-settings.dart';
import 'admin-profile.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  static const _navigationItems = [
    (Icons.grid_view_rounded, 'Dashboard'),
    (Icons.business_outlined, 'Organizer Applications'),
    (Icons.people_outline, 'Accounts'),
    (Icons.calendar_today_outlined, 'Events & Tickets'),
    (Icons.swap_vert_rounded, 'Resale Monitoring'),
    (Icons.shield_outlined, 'Fraud Alerts'),
    (Icons.bar_chart_rounded, 'Revenue & Reports'),
    (Icons.settings_outlined, 'Platform Settings'),
    (Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      drawer: isWide ? null : Drawer(child: _buildSidebar()),
      body: Row(
        children: [
          if (isWide) SizedBox(width: 180, child: _buildSidebar()),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isWide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWide ? 18 : 14),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final currentEmail =
        AdminSession.instance.currentEmail ?? 'admin@fairtix.com';

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
            for (var index = 0; index < _navigationItems.length; index++)
              _SidebarItem(
                icon: _navigationItems[index].$1,
                label: _navigationItems[index].$2,
                selected: index == _selectedIndex,
                onTap: () {
                  if (index == 1) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminOrganizerApplicationsScreen()),
                    );
                  } else if (index == 2) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminAccountsScreen()),
                    );
                  } else if (index == 3) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminEventsTicketsScreen()),
                    );
                  } else if (index == 4) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminResaleMonitoringScreen()),
                    );
                  } else if (index == 5) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminFraudAlertsScreen()),
                    );
                  } else if (index == 6) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminRevenueReportsScreen()),
                    );
                  } else if (index == 7) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminPlatformSettingsScreen()),
                    );
                  } else if (index == 8) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminProfileScreen()),
                    );
                  } else {
                    setState(() => _selectedIndex = index);
                  }
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
                    child: Icon(
                      Icons.person,
                      size: 17,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin', style: AppTextStyles.label),
                        Text(
                          currentEmail,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _confirmLogout,
                    icon: const Icon(
                      Icons.logout,
                      size: 17,
                      color: AppColors.textGray,
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

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
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
    if (!mounted || shouldLogout != true) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  Widget _buildTopBar(bool isWide) {
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
          const Spacer(),
          SizedBox(
            width: isWide ? 235 : 130,
            height: 32,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users, events...',
                hintStyle: const TextStyle(
                  color: Color(0xFFA6A9B7),
                  fontSize: 10,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 16,
                  color: Color(0xFFA6A9B7),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F3F6),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.notifications_none,
            size: 19,
            color: AppColors.textGray,
          ),
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFE8E6F1),
            child: Icon(Icons.person, size: 16, color: AppColors.textGray),
          ),
          if (isWide) ...[
            const SizedBox(width: 8),
            Text(
              AdminSession.instance.currentEmail ?? 'admin@fairtix.com',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard', style: AppTextStyles.h2),
                  SizedBox(height: 3),
                  Text('', style: AppTextStyles.bodyGray),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminAnnouncementScreen(),
                ),
              ),
              icon: const Icon(Icons.campaign_outlined, size: 14),
              label: const Text(
                'Create Announcement',
                style: TextStyle(fontSize: 10),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dashboard data refreshed.')),
                );
              },
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Refresh Data', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 800 ? 5 : 2;
            return GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 5 ? 1.75 : 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _MetricCard(icon: Icons.people_outline, label: 'TOTAL USERS'),
                _MetricCard(
                  icon: Icons.business_outlined,
                  label: 'TOTAL ORGANIZERS',
                ),
                _MetricCard(
                  icon: Icons.calendar_today_outlined,
                  label: 'TOTAL EVENTS',
                ),
                _MetricCard(
                  icon: Icons.confirmation_number_outlined,
                  label: 'TICKETS SOLD',
                ),
                _MetricCard(
                  icon: Icons.monetization_on_outlined,
                  label: 'PLATFORM REVENUE',
                  accent: true,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth > 760;
            final applications = _Panel(
              title: 'Pending Organizer Applications',
              action: 'View All',
            );
            final alerts = _Panel(
              title: 'Recent Fraud Alerts',
              action: 'View All',
              alert: true,
            );
            return sideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: applications),
                      const SizedBox(width: 16),
                      Expanded(child: alerts),
                    ],
                  )
                : Column(
                    children: [
                      applications,
                      const SizedBox(height: 16),
                      alerts,
                    ],
                  );
          },
        ),
        const SizedBox(height: 18),
        const _ActivityPanel(),
      ],
    );
  }
}

class _AdminLogo extends StatelessWidget {
  const _AdminLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
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
          child: const Icon(
            Icons.confirmation_number_outlined,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'FairTix',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 3),
        const Text(
          'ADMIN',
          style: TextStyle(fontSize: 8, color: AppColors.textGray),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textDark,
                ),
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
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;

  const _MetricCard({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: accent
                ? const Color(0xFFE1F8F0)
                : const Color(0xFFF0E9FF),
            child: Icon(
              icon,
              size: 15,
              color: accent ? AppColors.successGreen : AppColors.primaryPurple,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: AppColors.textGray, fontSize: 8),
          ),
          const SizedBox(height: 4),
          const Text(
            '—',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String action;
  final bool alert;

  const _Panel({required this.title, required this.action, this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.label.copyWith(fontSize: 12),
                ),
              ),
              Text(
                action,
                style: TextStyle(
                  color: alert ? AppColors.dangerRed : AppColors.primaryPurple,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(child: Text(' ', style: TextStyle(fontSize: 8))),
              Expanded(child: Text(' ', style: TextStyle(fontSize: 8))),
              Expanded(child: Text(' ', style: TextStyle(fontSize: 8))),
            ],
          ),
          const Divider(height: 12),
          SizedBox(
            height: 82,
            child: Center(
              child: Text(' ', style: TextStyle(color: AppColors.textGray)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Recent Activity Log', style: AppTextStyles.label),
              ),
              IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('There is no activity to export yet.'),
                  ),
                ),
                icon: const Icon(Icons.download_outlined, size: 16),
                tooltip: 'Export activity log',
              ),
            ],
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Text(
                'No recent activity yet. Activity will appear here once the backend is connected.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGray, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
