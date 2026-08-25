import 'package:flutter/material.dart';

import '../../services/admin_auth_service.dart';
import '../../services/admin_session.dart';
import '../organizer/app_colors.dart';
import 'admin-accounts.dart';
import 'admin-dashboard.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-login.dart';
import 'admin-organizer-applications.dart';
import 'admin-resale-monitoring.dart';
import 'admin-revenue-reports.dart';
import 'admin-route.dart';
import 'admin-profile.dart';

class AdminPlatformSettingsScreen extends StatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  State<AdminPlatformSettingsScreen> createState() =>
      _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState
    extends State<AdminPlatformSettingsScreen> {
  final _platformNameController = TextEditingController(text: 'FairTix');
  final _saleRateController = TextEditingController(text: '10');
  final _sessionTimeoutController = TextEditingController(text: '30');
  String _payoutSchedule = 'Monthly (1st of month)';
  bool _twoFactorRequired = true;
  bool _emailAlerts = true;
  bool _weeklyDigest = true;

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
  void dispose() {
    _platformNameController.dispose();
    _saleRateController.dispose();
    _sessionTimeoutController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, int index) {
    final pages = <int, Widget>{
      0: const AdminDashboardScreen(),
      1: const AdminOrganizerApplicationsScreen(),
      2: const AdminAccountsScreen(),
      3: const AdminEventsTicketsScreen(),
      4: const AdminResaleMonitoringScreen(),
      5: const AdminFraudAlertsScreen(),
      6: const AdminRevenueReportsScreen(),
      8: const AdminProfileScreen(),
    };
    final page = pages[index];
    if (page != null) {
      Navigator.pushReplacement(context, adminPageRoute(page));
    }
  }

  void _saveChanges(String section) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$section settings saved.')));
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
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

    if (!mounted || shouldLogout != true) return;

    AdminAuthService.instance.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

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
                selected: index == 7,
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

  Widget _buildTopBar(BuildContext context, bool isWide) {
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
          const Text('Platform Settings', style: AppTextStyles.label),
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

  Widget _buildContent(bool isWide) {
    final settings = <Widget>[
      _buildGeneralCard(),
      Column(
        children: [
          _buildPaymentCard(),
          const SizedBox(height: 14),
          _buildSecurityCard(),
          const SizedBox(height: 14),
          _buildNotificationsCard(),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text('Platform Settings', style: AppTextStyles.h2),
            ),
            if (isWide)
              const Text(
                'Last saved: Jun 26, 2026 - 3:42 PM',
                style: TextStyle(color: AppColors.textGray, fontSize: 10),
              ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'Manage global application rules and pricing structures.',
          style: TextStyle(color: AppColors.textGray, fontSize: 10),
        ),
        const SizedBox(height: 18),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: settings[0]),
              const SizedBox(width: 14),
              Expanded(child: settings[1]),
            ],
          )
        else
          Column(
            children: [settings[0], const SizedBox(height: 14), settings[1]],
          ),
      ],
    );
  }

  Widget _buildGeneralCard() => _SettingsCard(
    icon: Icons.percent,
    title: 'General',
    subtitle: 'Configure platform name and logo.',
    footer: 'Changes take effect immediately.',
    onSave: () => _saveChanges('General'),
    children: [
      _fieldLabel('Platform Name', 'Displayed in headers and emails.'),
      _input(_platformNameController, italic: true),
      const SizedBox(height: 18),
      _fieldLabel('Logo', 'Upload a square PNG (min 512x512).'),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => _saveChanges('Logo'),
          icon: const Icon(Icons.upload_outlined, size: 14),
          label: const Text('Upload logo', style: TextStyle(fontSize: 10)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryPurple,
            side: const BorderSide(color: AppColors.primaryPurple),
          ),
        ),
      ),
    ],
  );

  Widget _buildPaymentCard() => _SettingsCard(
    icon: Icons.bar_chart,
    title: 'Payment',
    subtitle: 'Configure fee percentages and payout schedule.',
    footer: 'Resale fee (all tiers): flat 5% of resale price.',
    onSave: () => _saveChanges('Payment'),
    children: [
      _fieldLabel(
        'Primary Sale Fee Rates',
        'Basic: 8% · Standard: 9% · Premium: 10% per ticket sold.',
      ),
      _input(
        _saleRateController,
        suffix: '%',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 18),
      _fieldLabel('Payout Schedule', 'When payouts are sent to organizers.'),
      DropdownButtonFormField<String>(
        initialValue: _payoutSchedule,
        items: const [
          DropdownMenuItem(
            value: 'Monthly (1st of month)',
            child: Text('Monthly (1st of month)'),
          ),
          DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
          DropdownMenuItem(
            value: 'After each event',
            child: Text('After each event'),
          ),
        ],
        onChanged: (value) =>
            setState(() => _payoutSchedule = value ?? _payoutSchedule),
        decoration: _inputDecoration(),
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildSecurityCard() => _SettingsCard(
    icon: Icons.shield_outlined,
    title: 'Security',
    subtitle: 'Control session timeout and 2FA requirements.',
    footer: 'This affects all administrator sessions.',
    footerColor: AppColors.dangerRed,
    onSave: () => _saveChanges('Security'),
    children: [
      _fieldLabel(
        'Session Timeout',
        'Minutes before requiring re-authentication.',
      ),
      _input(_sessionTimeoutController, keyboardType: TextInputType.number),
      const SizedBox(height: 14),
      _switchRow(
        '2FA Required',
        'Enforce two-factor authentication for all admins.',
        _twoFactorRequired,
        (value) => setState(() => _twoFactorRequired = value),
      ),
    ],
  );

  Widget _buildNotificationsCard() => _SettingsCard(
    icon: Icons.notifications_none,
    title: 'Notifications',
    subtitle: 'Control email notifications for system events.',
    onSave: () => _saveChanges('Notification'),
    children: [
      _switchRow(
        'Email Alerts',
        'Send emails for fraud alerts and system issues.',
        _emailAlerts,
        (value) => setState(() => _emailAlerts = value),
      ),
      const SizedBox(height: 14),
      _switchRow(
        'Weekly Digest',
        'Send a weekly summary of revenue and activity.',
        _weeklyDigest,
        (value) => setState(() => _weeklyDigest = value),
      ),
    ],
  );

  Widget _fieldLabel(String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(color: AppColors.textGray, fontSize: 8),
          ),
        ),
      ],
    ),
  );

  Widget _input(
    TextEditingController controller, {
    String? suffix,
    bool italic = false,
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    textAlign: suffix == null ? TextAlign.left : TextAlign.right,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    ),
    decoration: _inputDecoration(suffix: suffix),
  );

  InputDecoration _inputDecoration({String? suffix}) => InputDecoration(
    isDense: true,
    suffixText: suffix,
    suffixStyle: const TextStyle(color: AppColors.textGray, fontSize: 10),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
  );

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textGray, fontSize: 8),
            ),
          ],
        ),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primaryPurple,
      ),
    ],
  );
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? footer;
  final Color footerColor;
  final VoidCallback onSave;
  final List<Widget> children;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSave,
    required this.children,
    this.footer,
    this.footerColor = AppColors.textGray,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(icon, color: Colors.white, size: 13),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: Color(0xFFE9D5FF),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 8,
                  ),
                ),
                const SizedBox(height: 15),
                ...children,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                if (footer != null)
                  Expanded(
                    child: Text(
                      footer!,
                      style: TextStyle(color: footerColor, fontSize: 8),
                    ),
                  ),
                if (footer == null) const Spacer(),
                ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(105, 32),
                    minimumSize: const Size(105, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
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

class _AdminLogo extends StatelessWidget {
  const _AdminLogo();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(
          Icons.confirmation_number,
          color: Colors.white,
          size: 13,
        ),
      ),
      const SizedBox(width: 7),
      const Text(
        'FairTix',
        style: TextStyle(
          color: AppColors.primaryPurple,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
        ),
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
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppColors.textGray,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textGray,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
