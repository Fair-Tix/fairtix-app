import 'package:flutter/material.dart';

import '../../services/admin_auth_service.dart';
import '../../services/admin_session.dart';
import '../../services/password_service.dart';
import '../organizer/app_colors.dart';
import 'admin-accounts.dart';
import 'admin-dashboard.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-login.dart';
import 'admin-organizer-applications.dart';
import 'admin-platform-settings.dart';
import 'admin-resale-monitoring.dart';
import 'admin-revenue-reports.dart';
import 'admin-route.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isSavingPassword = false;

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
  void initState() {
    super.initState();
    _newPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
      7: const AdminPlatformSettingsScreen(),
    };
    final page = pages[index];
    if (page != null) {
      Navigator.pushReplacement(context, adminPageRoute(page));
    }
  }

  Future<void> _savePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSavingPassword = true);
    try {
      await PasswordService.instance.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on PasswordChangeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.dangerRed),
      );
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
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
                selected: index == 8,
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
    final currentEmail =
        AdminSession.instance.currentEmail ?? 'admin@fairtix.com';

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
          const Text('My Profile', style: AppTextStyles.label),
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
              currentEmail,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    final left = _buildIdentityCard();
    final right = Column(
      children: [
        _buildPasswordCard(),
        const SizedBox(height: 16),
        _buildActivityCard(isWide),
      ],
    );

    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: left),
              const SizedBox(width: 18),
              Expanded(flex: 6, child: right),
            ],
          )
        : Column(children: [left, const SizedBox(height: 16), right]);
  }

  Widget _buildIdentityCard() {
    final currentEmail =
        AdminSession.instance.currentEmail ?? 'admin@fairtix.com';
    final sessionLabel = currentEmail.split('@').first.trim();
    final isSignedIn = AdminSession.instance.isSignedIn;

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 33,
              backgroundColor: AppColors.primaryPurple,
              child: Text(
                sessionLabel.isNotEmpty ? sessionLabel[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              sessionLabel.isNotEmpty ? sessionLabel : 'Admin',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.infoBlueBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 11, color: AppColors.infoBlue),
                  SizedBox(width: 5),
                  Text(
                    'Administrator',
                    style: TextStyle(
                      color: AppColors.infoBlue,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Divider(height: 1),
            _profileDetail(
              Icons.mail_outline,
              'EMAIL',
              currentEmail,
              null,
            ),
            _profileDetail(
              Icons.calendar_today_outlined,
              'MEMBER SINCE',
              AdminSession.instance.memberSince != null
                  ? formatFriendlyDate(AdminSession.instance.memberSince!)
                  : '\u2014',
              null,
            ),
            _profileDetail(
              Icons.shield_outlined,
              'ROLE',
              'Administrator',
              null,
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'ACCOUNT STATUS',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSignedIn ? AppColors.successGreen : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isSignedIn ? 'Signed in' : 'Signed out',
                  style: TextStyle(
                    color: isSignedIn ? AppColors.successGreen : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileDetail(
    IconData icon,
    String label,
    String value,
    String? note,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 7),
                Text(
                  note,
                  style: const TextStyle(color: Color(0xFFA6A9B7), fontSize: 8),
                ),
              ],
            ],
          ),
        ),
        if (label != 'MEMBER SINCE')
          const Icon(Icons.lock_outline, size: 14, color: Color(0xFFB7BBC7)),
      ],
    ),
  );

  Widget _buildPasswordCard() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHeader(icon: Icons.lock_outline, title: 'Change Password'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _passwordField(
                  'Current Password',
                  _currentPasswordController,
                  _showCurrentPassword,
                  () => setState(
                    () => _showCurrentPassword = !_showCurrentPassword,
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter your current password.'
                      : null,
                ),
                const SizedBox(height: 15),
                _passwordField(
                  'New Password',
                  _newPasswordController,
                  _showNewPassword,
                  () => setState(() => _showNewPassword = !_showNewPassword),
                  validator: (value) => (value ?? '').length < 8
                      ? 'Use at least 8 characters.'
                      : null,
                ),
                const SizedBox(height: 8),
                _strengthIndicator(),
                const SizedBox(height: 15),
                _passwordField(
                  'Confirm New Password',
                  _confirmPasswordController,
                  _showConfirmPassword,
                  () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                  validator: (value) => value != _newPasswordController.text
                      ? 'Passwords do not match.'
                      : null,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your name and email stay locked to your admin account. Only your password can be changed here.',
                        style: TextStyle(color: Color(0xFFA6A9B7), fontSize: 8),
                      ),
                    ),
                    FilledButton(
                      onPressed: _isSavingPassword ? null : _savePassword,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isSavingPassword
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _passwordField(
    String label,
    TextEditingController controller,
    bool visible,
    VoidCallback onToggle, {
    String? Function(String?)? validator,
  }) => SizedBox(
    width: 310,
    child: TextFormField(
      controller: controller,
      obscureText: !visible,
      validator: validator,
      style: const TextStyle(fontSize: 10),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.textDark,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: '••••••••',
        hintStyle: const TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 17,
            color: const Color(0xFFA6A9B7),
          ),
          tooltip: visible ? 'Hide password' : 'Show password',
        ),
        contentPadding: const EdgeInsets.fromLTRB(10, 13, 4, 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
      ),
    ),
  );

  Widget _strengthIndicator() {
    final password = _newPasswordController.text;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    final String label;
    final Color color;
    if (password.isEmpty) {
      label = 'Enter a new password';
      color = const Color(0xFFA6A9B7);
    } else if (score <= 1) {
      label = 'Password strength: Weak';
      color = AppColors.dangerRed;
    } else if (score <= 3) {
      label = 'Password strength: Medium';
      color = AppColors.warningOrange;
    } else {
      label = 'Password strength: Strong';
      color = AppColors.successGreen;
    }

    Color barColor(int index) {
      final filled = password.isEmpty ? 0 : (score.clamp(0, 5) / 5 * 3).ceil();
      return index < filled ? color : const Color(0xFFE5E7EB);
    }

    return SizedBox(
      width: 310,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: barColor(0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(height: 4, color: barColor(1)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: barColor(2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(bool isWide) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHeader(
          icon: Icons.access_time,
          title: 'Recent Activity',
          action: 'View Full Log',
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Activity logging isn\u2019t built yet \u2014 actions you take (approvals, suspensions, etc.) aren\u2019t recorded to a log for display here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: isWide ? 11 : 10,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.borderLight),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? action;
  const _PanelHeader({required this.icon, required this.title, this.action});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.borderLight)),
    ),
    child: Row(
      children: [
        Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: const Color(0xFFF0E9FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryPurple, size: 15),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        if (action != null) ...[
          const Spacer(),
          Text(
            action!,
            style: const TextStyle(
              color: AppColors.primaryPurple,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
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
