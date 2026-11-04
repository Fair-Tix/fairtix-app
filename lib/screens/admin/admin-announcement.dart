import 'package:flutter/material.dart';

import '../../services/admin_session.dart';
import '../../services/admin_user_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_shell.dart';
import '../organizer/app_colors.dart';
import 'admin-accounts.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-login.dart';
import 'admin-organizer-applications.dart';
import 'admin-resale-monitoring.dart';
import 'admin-route.dart';
import 'admin-revenue-reports.dart';
import 'admin-platform-settings.dart';
import 'admin-profile.dart';

class AdminAnnouncementScreen extends StatefulWidget {
  const AdminAnnouncementScreen({super.key});

  @override
  State<AdminAnnouncementScreen> createState() =>
      _AdminAnnouncementScreenState();
}

class _AdminAnnouncementScreenState extends State<AdminAnnouncementScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController
      ..removeListener(_onMessageChanged)
      ..dispose();
    super.dispose();
  }

  void _onMessageChanged() => setState(() {});

  /// Delivers the announcement as an in-app notification to every verified,
  /// active buyer and organizer (the `send_announcement` RPC, see
  /// supabase/organizer_event_functions.sql), then reports how many people
  /// received it.
  Future<void> _sendAnnouncement() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await AdminUserService.instance.sendAnnouncement(
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        audience: 'all',
      );
      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'No eligible users to notify yet.'
                : 'Announcement sent to $count user${count == 1 ? '' : 's'}.',
          ),
        ),
      );
    } on AdminUserServiceException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return AdminShell(
      active: AdminNavItem.dashboard,
      title: 'Platform Announcement',
      body: _buildContent(isWide),
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
            _SidebarItem(
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            _SidebarItem(
              icon: Icons.business_outlined,
              label: 'Organizer Applications',
              onTap: () => adminPushReplacement(
                context,
                const AdminOrganizerApplicationsScreen(),
              ),
            ),
            _SidebarItem(
              icon: Icons.people_outline,
              label: 'Accounts',
              onTap: () =>
                  adminPushReplacement(context, const AdminAccountsScreen()),
            ),
            _SidebarItem(
              icon: Icons.calendar_today_outlined,
              label: 'Events & Tickets',
              onTap: () => adminPushReplacement(
                context,
                const AdminEventsTicketsScreen(),
              ),
            ),
            _SidebarItem(
              icon: Icons.swap_vert_rounded,
              label: 'Resale Monitoring',
              onTap: () => adminPushReplacement(
                context,
                const AdminResaleMonitoringScreen(),
              ),
            ),
            _SidebarItem(
              icon: Icons.shield_outlined,
              label: 'Fraud Alerts',
              onTap: () =>
                  adminPushReplacement(context, const AdminFraudAlertsScreen()),
            ),
            _SidebarItem(
              icon: Icons.bar_chart_rounded,
              label: 'Revenue & Reports',
              onTap: () => adminPushReplacement(
                context,
                const AdminRevenueReportsScreen(),
              ),
            ),
            _SidebarItem(
              icon: Icons.settings_outlined,
              label: 'Platform Settings',
              onTap: () => adminPushReplacement(
                context,
                const AdminPlatformSettingsScreen(),
              ),
            ),
            _SidebarItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () =>
                  adminPushReplacement(context, const AdminProfileScreen()),
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
          Text('Platform Announcement', style: AppTextStyles.label),
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
    final palette = FairTixPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Announcement',
          style: AppTextStyles.h2.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 3),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 585),
          child: Container(
            padding: EdgeInsets.all(isWide ? 26 : 18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'New Platform Announcement',
                    style: AppTextStyles.h3.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Broadcast a message to all FairTix users and organizers',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _label('SUBJECT'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _subjectController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Subject is required'
                        : null,
                    decoration: _inputDecoration(
                      'e.g. Scheduled maintenance on July 10',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _label('MESSAGE'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _messageController,
                    maxLength: 1000,
                    maxLines: 6,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Message is required'
                        : null,
                    decoration:
                        _inputDecoration(
                          'Write your platform-wide message here...',
                        ).copyWith(
                          counterText:
                              '${_messageController.text.length} / 1000',
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 14,
                            color: palette.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Audience: All verified users & organizers',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: _isSending ? null : _sendAnnouncement,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined, size: 14),
                          label: Text(
                            _isSending ? 'Sending...' : 'Send Announcement',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 585),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.warningSurface,
              border: Border.all(color: palette.warningBorder),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.volume_off_outlined,
                  size: 16,
                  color: palette.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will be sent platform-wide to all verified users and organizers.',
                    style: TextStyle(color: palette.warning, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: FairTixPalette.of(context).textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    ),
  );

  InputDecoration _inputDecoration(String hint) {
    final palette = FairTixPalette.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: palette.textSecondary, fontSize: 11),
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: palette.primary),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to return to the admin login screen?',
        ),
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
    adminPushAndRemoveUntil(context, const AdminLoginScreen());
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
    this.selected = false,
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
