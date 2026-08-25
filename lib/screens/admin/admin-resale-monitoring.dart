import 'package:flutter/material.dart';

import '../../services/admin_session.dart';
import '../../services/event_repository.dart';
import '../organizer/app_colors.dart';
import 'admin-accounts.dart';
import 'admin-dashboard.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-login.dart';
import 'admin-organizer-applications.dart';
import 'admin-route.dart';
import 'admin-revenue-reports.dart';
import 'admin-platform-settings.dart';
import 'admin-profile.dart';

class AdminResaleMonitoringScreen extends StatefulWidget {
  const AdminResaleMonitoringScreen({super.key});

  @override
  State<AdminResaleMonitoringScreen> createState() =>
      _AdminResaleMonitoringScreenState();
}

class _AdminResaleMonitoringScreenState
    extends State<AdminResaleMonitoringScreen> {
  final _searchController = TextEditingController();
  String _status = 'All';
  bool _showTransactionLog = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigate(int index) {
    final pages = <int, Widget>{
      0: const AdminDashboardScreen(),
      1: const AdminOrganizerApplicationsScreen(),
      2: const AdminAccountsScreen(),
      3: const AdminEventsTicketsScreen(),
      5: const AdminFraudAlertsScreen(),
      6: const AdminRevenueReportsScreen(),
      7: const AdminPlatformSettingsScreen(),
      8: const AdminProfileScreen(),
    };
    final page = pages[index];
    if (page != null) {
      Navigator.pushReplacement(context, adminPageRoute(page));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;
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
                    child: _buildContent(isWide),
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
    const items = [
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
            for (var index = 0; index < items.length; index++)
              _SidebarItem(
                icon: items[index].$1,
                label: items[index].$2,
                selected: index == 4,
                onTap: () => _navigate(index),
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
          const Text('Resale Monitor', style: AppTextStyles.label),
          const Spacer(),
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

  Widget _buildContent(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Resale Monitoring', style: AppTextStyles.h2),
            ),
            OutlinedButton.icon(
              onPressed: _exportCsv,
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
        _buildSummaryCards(),
        const SizedBox(height: 18),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: _buildListings()),
              if (_showTransactionLog) ...[
                const SizedBox(width: 18),
                Expanded(flex: 3, child: _buildTransactionLog()),
              ],
            ],
          )
        else ...[
          _buildListings(),
          if (_showTransactionLog) ...[
            const SizedBox(height: 18),
            _buildTransactionLog(),
          ],
        ],
      ],
    );
  }

  Widget _buildSummaryCards() {
    final events = EventRepository.instance.events;
    final cards = [
      (
        Icons.sell_outlined,
        const Color(0xFFEF4444),
        'Suspicious Listings',
        '0',
        'No listings yet',
      ),
      (
        Icons.shield_outlined,
        AppColors.primaryPurple,
        'Total Volume',
        '₱0',
        'No resale volume yet',
      ),
      (
        Icons.percent_outlined,
        const Color(0xFFF59E0B),
        'Avg Markup',
        '0%',
        '${events.length} events monitored',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 16,
        runSpacing: 12,
        children: cards.map((card) {
          return SizedBox(
            width: constraints.maxWidth > 760
                ? (constraints.maxWidth - 32) / 3
                : constraints.maxWidth,
            child: Container(
              height: 116,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: card.$2.withValues(alpha: 0.12),
                        child: Icon(card.$1, size: 16, color: card.$2),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        card.$3,
                        style: const TextStyle(
                          color: AppColors.textGray,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    card.$4,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    card.$5,
                    style: TextStyle(
                      color: card.$2 == const Color(0xFFEF4444)
                          ? AppColors.dangerRed
                          : AppColors.textGray,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListings() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search seller or event...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 17,
                        color: AppColors.textGray,
                      ),
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
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _status,
                  items: const ['All', 'Active', 'Flagged', 'Suspended']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _status = value!),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(child: Text('SELLER', style: _headerStyle)),
                Expanded(child: Text('EVENT', style: _headerStyle)),
                Expanded(child: Text('ORIG. PRICE', style: _headerStyle)),
                Expanded(child: Text('RESALE PRICE', style: _headerStyle)),
                Expanded(child: Text('MARKUP %', style: _headerStyle)),
                Expanded(child: Text('STATUS', style: _headerStyle)),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.swap_vert_rounded,
                    size: 38,
                    color: Color(0xFFD9D7E4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No resale listings yet',
                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _searchController.text.isEmpty
                        ? 'Resale activity will appear here when tickets are listed.'
                        : 'No listings match your search.',
                    style: const TextStyle(
                      color: Color(0xFFA6A9B7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Text(
                  'Showing 0 of 0 listings',
                  style: TextStyle(color: AppColors.textGray, fontSize: 10),
                ),
                const Spacer(),
                TextButton(
                  onPressed: null,
                  child: const Text('Previous', style: TextStyle(fontSize: 10)),
                ),
                TextButton(
                  onPressed: null,
                  child: const Text('Next', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionLog() {
    return Container(
      constraints: const BoxConstraints(minHeight: 430),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Transaction Log', style: AppTextStyles.h3),
              ),
              IconButton(
                onPressed: () => setState(() => _showTransactionLog = false),
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 120),
          const Icon(
            Icons.receipt_long_outlined,
            size: 34,
            color: Color(0xFFD9D7E4),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'No transactions yet',
              style: TextStyle(color: AppColors.textGray, fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Transaction details will appear when resale activity begins.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _exportCsv() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('There are no resale listings to export yet.'),
    ),
  );

  Future<void> _confirmLogout() async {
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
    if (!mounted || confirmed != true) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }
}

const _headerStyle = TextStyle(
  color: AppColors.textGray,
  fontSize: 9,
  fontWeight: FontWeight.w700,
);

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
