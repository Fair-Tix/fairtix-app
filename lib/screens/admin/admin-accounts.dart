import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../services/admin_session.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_document_viewer.dart';
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

/// All registered accounts (buyers, organizers, admins) with manual ID
/// verification review. Reads/writes `public.users` directly via
/// [AdminUserService] — see supabase/schema.sql (Table 6) and
/// supabase/policies.sql (`users_select_own_or_admin` /
/// `users_update_own_or_admin`, which are what actually let an admin
/// session see and modify rows other than its own).
class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
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

  static const _roleFilters = ['All', 'Buyer', 'Organizer', 'Admin'];
  static const _verificationFilters = ['All', 'Pending', 'Verified', 'Rejected'];

  List<AdminUserSummary> _users = [];
  bool _isLoading = true;
  String? _loadError;

  String _roleFilter = 'All';
  String _verificationFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final users = await AdminUserService.instance.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } on AdminUserServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  List<AdminUserSummary> get _filteredUsers {
    return _users.where((u) {
      if (_roleFilter != 'All' && u.role != _roleFilter.toLowerCase()) {
        return false;
      }
      if (_verificationFilter != 'All' &&
          u.idVerificationStatus != _verificationFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final haystack = '${u.fullName} ${u.username} ${u.email}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _reviewUser(AdminUserSummary user) async {
    await showAdminReviewDialog(
      context: context,
      title: user.fullName,
      subtitle:
          '${_roleLabel(user.role)} \u2022 Submitted ${user.createdAt != null ? formatFriendlyDate(user.createdAt!) : 'unknown date'}',
      currentStatus: user.idVerificationStatus,
      documents: [
        AdminReviewDocument(
          label: 'ID Document${user.idType != null ? ' (${user.idType})' : ''}',
          bucket: 'identity_docs',
          path: user.idDocumentUrl,
        ),
        AdminReviewDocument(
          label: 'Live Selfie',
          bucket: 'identity_docs',
          path: user.selfiePhotoUrl,
        ),
      ],
      onApprove: () => _decide(user, 'verified'),
      onReject: () => _decide(user, 'rejected'),
    );
  }

  Future<void> _decide(AdminUserSummary user, String status) async {
    await AdminUserService.instance.setIdVerificationStatus(
      userId: user.id,
      status: status,
    );
    await _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'verified'
              ? '${user.fullName} has been verified.'
              : '${user.fullName}\'s application was rejected.',
        ),
      ),
    );
  }

  Future<void> _toggleAccountStatus(AdminUserSummary user) async {
    final nextStatus = user.accountStatus == 'suspended' ? 'active' : 'suspended';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextStatus == 'suspended' ? 'Suspend account?' : 'Reactivate account?'),
        content: Text(
          nextStatus == 'suspended'
              ? '${user.fullName} will not be able to log in until reactivated.'
              : '${user.fullName} will be able to log in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: nextStatus == 'suspended' ? AppColors.dangerRed : AppColors.successGreen,
            ),
            child: Text(nextStatus == 'suspended' ? 'Suspend' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AdminUserService.instance.setAccountStatus(userId: user.id, status: nextStatus);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.fullName} is now $nextStatus.')),
      );
    } on AdminUserServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static String _roleLabel(String role) => switch (role) {
        'organizer' => 'Organizer',
        'admin' => 'Admin',
        _ => 'Buyer',
      };

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
    final currentEmail = AdminSession.instance.currentEmail ?? 'admin@fairtix.com';

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
                    child: Icon(Icons.person, size: 17, color: AppColors.textGray),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin', style: AppTextStyles.label),
                        Text(
                          currentEmail,
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

  void _navigate(BuildContext context, int index) {
    final pages = <int, Widget>{
      0: const AdminDashboardScreen(),
      1: const AdminOrganizerApplicationsScreen(),
      3: const AdminEventsTicketsScreen(),
      4: const AdminResaleMonitoringScreen(),
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
          const Text('User Accounts', style: AppTextStyles.label),
          const Spacer(),
          SizedBox(
            width: isWide ? 270 : 130,
            height: 32,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search users, events...',
                hintStyle: const TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFFA6A9B7)),
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
          const Icon(Icons.notifications_none, size: 19, color: AppColors.textGray),
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
    final filtered = _filteredUsers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('User Accounts', style: AppTextStyles.h2)),
            IconButton(
              onPressed: _isLoading ? null : _loadUsers,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh',
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
              BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Role:', style: TextStyle(color: AppColors.textGray, fontSize: 10)),
              _filterMenu(_roleFilter, _roleFilters, (v) => setState(() => _roleFilter = v)),
              const Text('Verification:', style: TextStyle(color: AppColors.textGray, fontSize: 10)),
              _filterMenu(
                _verificationFilter,
                _verificationFilters,
                (v) => setState(() => _verificationFilter = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              if (isWide)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFFFBFBFD),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('USER DETAILS', style: _headerStyle)),
                      Expanded(child: Text('EMAIL', style: _headerStyle)),
                      Expanded(child: Text('ROLE', style: _headerStyle)),
                      Expanded(child: Text('VERIFIED', style: _headerStyle)),
                      Expanded(child: Text('JOINED', style: _headerStyle)),
                      Expanded(child: Text('STATUS', style: _headerStyle)),
                      SizedBox(width: 150, child: Text('ACTIONS', style: _headerStyle)),
                    ],
                  ),
                ),
              const Divider(height: 1),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              else if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(_loadError!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 12)),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _loadUsers, child: const Text('Retry')),
                    ],
                  ),
                )
              else if (filtered.isEmpty)
                const _EmptyAccounts()
              else
                Column(
                  children: [
                    for (final user in filtered) _UserRow(user: user, isWide: isWide, screen: this),
                  ],
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      'Showing ${filtered.length} of ${_users.length} accounts',
                      style: const TextStyle(color: AppColors.textGray, fontSize: 10),
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

  Widget _filterMenu(String value, List<String> options, ValueChanged<String> onChanged) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options) PopupMenuItem(value: option, child: Text(option)),
      ],
      child: Container(
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
            const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to Log Out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
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

const _headerStyle = TextStyle(color: AppColors.textGray, fontSize: 9, fontWeight: FontWeight.w700);

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.isWide, required this.screen});

  final AdminUserSummary user;
  final bool isWide;
  final _AdminAccountsScreenState screen;

  @override
  Widget build(BuildContext context) {
    final verifiedBadge = _StatusBadge.verification(user.idVerificationStatus);
    final statusBadge = _StatusBadge.account(user.accountStatus);
    final joined = user.createdAt != null ? formatFriendlyDate(user.createdAt!) : '\u2014';

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: user.hasReviewableDocuments ? () => screen._reviewUser(user) : null,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
          child: Text(
            user.idVerificationStatus == 'pending' ? 'Review' : 'View',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => screen._toggleAccountStatus(user),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            foregroundColor: user.accountStatus == 'suspended' ? AppColors.successGreen : AppColors.dangerRed,
          ),
          child: Text(
            user.accountStatus == 'suspended' ? 'Reactivate' : 'Suspend',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    if (!isWide) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Text(user.email, style: const TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                    ],
                  ),
                ),
                verifiedBadge,
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_AdminAccountsScreenState._roleLabel(user.role), style: const TextStyle(fontSize: 10.5)),
                const SizedBox(width: 10),
                statusBadge,
                const Spacer(),
                Text(joined, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
              ],
            ),
            const SizedBox(height: 6),
            actions,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                if (user.username.isNotEmpty)
                  Text('@${user.username}', style: const TextStyle(fontSize: 10.5, color: AppColors.textGray)),
              ],
            ),
          ),
          Expanded(child: Text(user.email, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          Expanded(child: Text(_AdminAccountsScreenState._roleLabel(user.role), style: const TextStyle(fontSize: 11))),
          Expanded(child: verifiedBadge),
          Expanded(child: Text(joined, style: const TextStyle(fontSize: 10.5, color: AppColors.textGray))),
          Expanded(child: statusBadge),
          SizedBox(width: 150, child: actions),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color, required this.bgColor});

  final String label;
  final Color color;
  final Color bgColor;

  factory _StatusBadge.verification(String status) {
    switch (status) {
      case 'verified':
        return const _StatusBadge(label: 'Verified', color: AppColors.successGreen, bgColor: AppColors.successGreenBg);
      case 'rejected':
        return const _StatusBadge(label: 'Rejected', color: AppColors.dangerRed, bgColor: AppColors.dangerRedBg);
      default:
        return const _StatusBadge(label: 'Pending', color: AppColors.warningOrange, bgColor: AppColors.warningOrangeBg);
    }
  }

  factory _StatusBadge.account(String status) {
    switch (status) {
      case 'suspended':
        return const _StatusBadge(label: 'Suspended', color: AppColors.dangerRed, bgColor: AppColors.dangerRedBg);
      case 'deactivated':
        return const _StatusBadge(label: 'Deactivated', color: AppColors.textGray, bgColor: Color(0xFFF3F4F6));
      default:
        return const _StatusBadge(label: 'Active', color: AppColors.successGreen, bgColor: AppColors.successGreenBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 36, color: Color(0xFFD9D7E4)),
              SizedBox(height: 10),
              Text('No matching accounts', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
              SizedBox(height: 4),
              Text(
                'Try a different filter or check back once users register.',
                style: TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
              ),
            ],
          ),
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
            decoration: BoxDecoration(color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(5)),
            child: const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 6),
          const Text('FairTix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
          const SizedBox(width: 3),
          const Text('ADMIN', style: TextStyle(fontSize: 8, color: AppColors.textGray)),
        ],
      );
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.onTap});

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
}
