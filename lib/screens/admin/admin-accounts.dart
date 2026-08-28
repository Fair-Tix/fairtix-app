import 'package:flutter/material.dart';

import '../../services/admin_session.dart';
import '../organizer/app_colors.dart';
import 'admin-dashboard.dart';
import 'admin-login.dart';
import 'admin-organizer-applications.dart';
import 'admin-route.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-resale-monitoring.dart';
import 'admin-revenue-reports.dart';
import 'admin-platform-settings.dart';
import 'admin-profile.dart';

class AdminAccountsScreen extends StatelessWidget {
  const AdminAccountsScreen({super.key});

  static const _items = [
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
      drawer: isWide ? null : Drawer(child: _buildSidebar(context)),
      body: Row(
        children: [
          if (isWide) SizedBox(width: 180, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, isWide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWide ? 18 : 14),
                    child: _buildContent(context, isWide),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
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
            for (var index = 0; index < _items.length; index++)
              _SidebarItem(
                icon: _items[index].$1,
                label: _items[index].$2,
                selected: index == 2,
                onTap: () => _navigate(context, index),
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
                    onPressed: () => _logout(context),
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

  void _navigate(BuildContext context, int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        adminPageRoute(const AdminDashboardScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        adminPageRoute(const AdminOrganizerApplicationsScreen()),
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
    }
  }

  Widget _buildTopBar(BuildContext context, bool isWide) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, size: 20),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const Text('User Accounts', style: AppTextStyles.label),
          const Spacer(),
          SizedBox(
            width: isWide ? 270 : 130,
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

  Widget _buildContent(BuildContext context, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('User Accounts', style: AppTextStyles.h2),
            ),
            OutlinedButton.icon(
              onPressed: () => _showMessage(
                context,
                'There is no account data to export yet.',
              ),
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export CSV', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isWide ? 390 : 220,
                height: 30,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by username, name, or email...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFA6A9B7),
                      fontSize: 11,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 17,
                      color: AppColors.textGray,
                    ),
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: const Color(0xFFF8F7FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                  ),
                ),
              ),
              const Text(
                'Role:',
                style: TextStyle(color: AppColors.textGray, fontSize: 10),
              ),
              _filterMenu('All'),
              const Text(
                'Status:',
                style: TextStyle(color: AppColors.textGray, fontSize: 10),
              ),
              _filterMenu('All'),
              ElevatedButton(
                onPressed: () => _showMessage(
                  context,
                  'Filters applied. No accounts match yet.',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: isWide ? 430 : 470,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: const Color(0xFFFBFBFD),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('USER DETAILS', style: _headerStyle),
                    ),
                    Expanded(child: Text('EMAIL', style: _headerStyle)),
                    Expanded(child: Text('ROLE', style: _headerStyle)),
                    Expanded(child: Text('VERIFIED', style: _headerStyle)),
                    Expanded(child: Text('JOINED', style: _headerStyle)),
                    Expanded(child: Text('STATUS', style: _headerStyle)),
                    SizedBox(
                      width: 82,
                      child: Text('ACTIONS', style: _headerStyle),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Expanded(child: _EmptyAccounts()),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      'Showing 0 of 0 accounts',
                      style: TextStyle(color: AppColors.textGray, fontSize: 10),
                    ),
                    Spacer(),
                    Text(
                      'Previous',
                      style: TextStyle(color: Color(0xFFB4B5C0), fontSize: 10),
                    ),
                    SizedBox(width: 24),
                    Text(
                      'Next',
                      style: TextStyle(color: Color(0xFFB4B5C0), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterMenu(String value) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.borderLight),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 14),
        const Icon(
          Icons.keyboard_arrow_down,
          size: 14,
          color: AppColors.textGray,
        ),
      ],
    ),
  );

  void _showMessage(BuildContext context, String message) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

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
    if (confirmed == true && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }
}

const _headerStyle = TextStyle(
  color: AppColors.textGray,
  fontSize: 9,
  fontWeight: FontWeight.w700,
);

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people_outline, size: 36, color: Color(0xFFD9D7E4)),
        const SizedBox(height: 10),
        const Text(
          'No user accounts yet',
          style: TextStyle(color: AppColors.textGray, fontSize: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          'Accounts will appear here when users register.',
          style: TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
        ),
      ],
    ),
  );
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
