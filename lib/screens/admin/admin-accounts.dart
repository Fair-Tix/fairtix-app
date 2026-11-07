import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../services/admin_user_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_document_viewer.dart'
    show AdminReviewDocument, showAdminReviewDialog;
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/ft_skeleton.dart';
import '../../widgets/organizer_ui.dart';

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
  static const _roleFilters = ['All', 'Buyer', 'Organizer'];

  /// Relative column widths (user, email, role, verified, joined, status,
  /// actions). Header and rows share these.
  static const _flex = [3, 4, 2, 2, 2, 2, 4];

  List<AdminUserSummary> _users = [];
  bool _isLoading = true;
  String? _loadError;
  String _roleFilter = 'All';
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
      final users = await AdminUserService.instance.fetchUsers(
        onlyApproved: true,
      );
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
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final haystack = '${u.fullName} ${u.username} ${u.email}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  static String _joinedOn(AdminUserSummary u) =>
      u.createdAt != null ? formatAdminDate(u.createdAt!.toLocal()) : '\u2014';

  Future<void> _reviewUser(AdminUserSummary user) async {
    await showAdminReviewDialog(
      context: context,
      title: user.fullName,
      subtitle:
          '${_roleLabel(user.role)} \u2022 Submitted ${user.createdAt != null ? _joinedOn(user) : 'unknown date'}',
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
    final p = FairTixPalette.of(context);
    final nextStatus = user.accountStatus == 'suspended'
        ? 'active'
        : 'suspended';
    final suspending = nextStatus == 'suspended';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
        title: Text(
          suspending ? 'Suspend account?' : 'Reactivate account?',
          style: orgText(p, size: 18, weight: FontWeight.w800),
        ),
        content: Text(
          suspending
              ? '${user.fullName} will not be able to log in until reactivated.'
              : '${user.fullName} will be able to log in again.',
          style: orgText(p, size: 14, color: p.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: orgText(p, size: 14, weight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              suspending ? 'Suspend' : 'Reactivate',
              style: orgText(
                p,
                size: 14,
                weight: FontWeight.w700,
                color: suspending ? p.danger : p.success,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AdminUserService.instance.setAccountStatus(
        userId: user.id,
        status: nextStatus,
      );
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.fullName} is now $nextStatus.')),
      );
    } on AdminUserServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
    return AdminShell(
      active: AdminNavItem.accounts,
      title: 'Accounts',
      body: _buildContent(context, isWide),
    );
  }

  Widget _buildContent(BuildContext context, bool isWide) {
    final p = FairTixPalette.of(context);
    final filtered = _filteredUsers;

    final Widget content;
    if (_isLoading) {
      content = FtShimmer(
        child: AdminSkeletonTableBody(flex: _flex, compact: !isWide),
      );
    } else if (_loadError != null) {
      content = AdminErrorBox(message: _loadError!, onRetry: _loadUsers);
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide)
            const AdminTableHeader(
              labels: [
                'User details',
                'Email',
                'Role',
                'Verified',
                'Joined',
                'Status',
                'Actions',
              ],
              flex: _flex,
            ),
          if (filtered.isEmpty)
            const AdminEmptyState(
              icon: Icons.people_outline,
              title: 'No matching accounts',
              hint: 'Try a different filter or check back once users register.',
            )
          else
            for (final user in filtered)
              _UserRow(user: user, isWide: isWide, flex: _flex, screen: this),
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Showing ${filtered.length} of ${_users.length} accounts',
              style: orgText(p, size: 12, color: p.textSecondary),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'User Accounts',
          subtitle: 'Approved, registered users only.',
          actions: [
            AdminIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh data',
              loading: _isLoading,
              onPressed: _isLoading ? null : _loadUsers,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminFilterChips(
          labels: _roleFilters,
          selected: _roleFilters.indexOf(_roleFilter),
          onSelected: (i) => setState(() => _roleFilter = _roleFilters[i]),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminSearchField(
            hint: 'Search name, username or email',
            width: isWide ? 320 : 260,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(height: 20),
        AdminCard(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 200),
              child: content,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isWide,
    required this.flex,
    required this.screen,
  });

  final AdminUserSummary user;
  final bool isWide;
  final List<int> flex;
  final _AdminAccountsScreenState screen;

  static AdminBadge _verificationBadge(String status) => switch (status) {
    'verified' => AdminBadge.success('Verified'),
    'rejected' => AdminBadge.danger('Rejected'),
    _ => AdminBadge.warning('Pending'),
  };

  static AdminBadge _accountBadge(String status) => switch (status) {
    'suspended' => AdminBadge.danger('Suspended'),
    'deactivated' => AdminBadge.neutral('Deactivated'),
    _ => AdminBadge.success('Active'),
  };

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final verifiedBadge = _verificationBadge(user.idVerificationStatus);
    final statusBadge = _accountBadge(user.accountStatus);
    final joined = _AdminAccountsScreenState._joinedOn(user);
    final suspended = user.accountStatus == 'suspended';
    final pending = user.idVerificationStatus == 'pending';

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AdminRowAction(
          label: pending ? 'Review' : 'View',
          filled: pending && user.canReview,
          onPressed: user.canReview ? () => screen._reviewUser(user) : null,
        ),
        AdminRowAction(
          label: suspended ? 'Reactivate' : 'Suspend',
          color: suspended ? p.success : p.danger,
          onPressed: () => screen._toggleAccountStatus(user),
        ),
      ],
    );

    if (!isWide) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: orgText(p, size: 15, weight: FontWeight.w700),
                      ),
                      Text(
                        user.email,
                        overflow: TextOverflow.ellipsis,
                        style: orgText(p, size: 13, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                verifiedBadge,
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _AdminAccountsScreenState._roleLabel(user.role),
                  style: orgText(p, size: 13),
                ),
                const SizedBox(width: 10),
                statusBadge,
                const Spacer(),
                Text(
                  joined,
                  style: orgText(p, size: 12, color: p.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            actions,
          ],
        ),
      );
    }

    return AdminTableRow(
      children: [
        Expanded(
          flex: flex[0],
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(
                    p,
                    size: 14,
                    weight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (user.username.isNotEmpty)
                  Text(
                    '@${user.username}',
                    overflow: TextOverflow.ellipsis,
                    style: orgText(
                      p,
                      size: 12,
                      color: p.textSecondary,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
        ),
        adminCell(context, flex[1], user.email),
        adminCell(
          context,
          flex[2],
          _AdminAccountsScreenState._roleLabel(user.role),
        ),
        Expanded(
          flex: flex[3],
          child: Align(alignment: Alignment.centerLeft, child: verifiedBadge),
        ),
        adminCell(context, flex[4], joined, muted: true),
        Expanded(
          flex: flex[5],
          child: Align(alignment: Alignment.centerLeft, child: statusBadge),
        ),
        Expanded(flex: flex[6], child: actions),
      ],
    );
  }
}
