import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../theme/fairtix_palette.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_document_viewer.dart'
    show AdminReviewDocument, showAdminReviewDialog;
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';

/// Eventgoer (buyer) sign-ups waiting for, or already given, an admin
/// decision. This is the review queue for the registration flow in the
/// manuscript: email OTP, then ID upload, then live selfie, then admin
/// approval before the account can buy, use, or resell tickets.
///
/// Reads `public.users` where `role = 'buyer'` via [AdminUserService] and
/// approves/rejects through the same `admin_review_account` RPC the
/// Organizer Applications screen uses, so the person is notified in the
/// same transaction. The Accounts screen only lists approved users, which
/// is why pending and rejected sign-ups needed a queue of their own.
class AdminUserRegistrationsScreen extends StatefulWidget {
  const AdminUserRegistrationsScreen({super.key});

  @override
  State<AdminUserRegistrationsScreen> createState() =>
      _AdminUserRegistrationsScreenState();
}

/// Where a sign-up currently is. "Incomplete" means they verified their
/// email but haven't uploaded an ID yet, so there is nothing to review.
enum _Stage { incomplete, pending, approved, rejected }

_Stage _stageOf(AdminUserSummary user) {
  switch (user.idVerificationStatus) {
    case 'verified':
      return _Stage.approved;
    case 'rejected':
      return _Stage.rejected;
    default:
      return user.idDocumentUrl == null ? _Stage.incomplete : _Stage.pending;
  }
}

AdminBadge _stageBadge(_Stage stage) => switch (stage) {
  _Stage.approved => AdminBadge.success('Approved'),
  _Stage.rejected => AdminBadge.danger('Rejected'),
  _Stage.incomplete => AdminBadge.neutral('Incomplete'),
  _Stage.pending => AdminBadge.warning('Pending'),
};

String _registeredOn(AdminUserSummary u) =>
    u.createdAt != null ? formatAdminDate(u.createdAt!.toLocal()) : '\u2014';

class _AdminUserRegistrationsScreenState
    extends State<AdminUserRegistrationsScreen> {
  static const _filters = [
    'Pending',
    'Approved',
    'Rejected',
    'Incomplete',
    'All',
  ];

  /// Relative column widths (name, email, ID type, registered, status,
  /// action). Header and rows share these.
  static const _flex = [3, 4, 2, 2, 2, 2];

  String _filter = 'Pending'; // the actionable queue
  String _search = '';

  List<AdminUserSummary> _users = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final users = await AdminUserService.instance.fetchUsers(role: 'buyer');
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

  int _countFor(String filter) =>
      _users.where((u) => _matches(u, filter)).length;

  bool _matches(AdminUserSummary user, String filter) {
    final stage = _stageOf(user);
    return switch (filter) {
      'Pending' => stage == _Stage.pending,
      'Approved' => stage == _Stage.approved,
      'Rejected' => stage == _Stage.rejected,
      'Incomplete' => stage == _Stage.incomplete,
      _ => true,
    };
  }

  List<AdminUserSummary> get _visible {
    final q = _search.trim().toLowerCase();
    return _users.where((u) {
      if (!_matches(u, _filter)) return false;
      if (q.isEmpty) return true;
      return '${u.fullName} ${u.username} ${u.email}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _review(AdminUserSummary user) async {
    await showAdminReviewDialog(
      context: context,
      title: user.fullName,
      subtitle:
          '${user.email} \u2022 Registered ${user.createdAt != null ? _registeredOn(user) : 'unknown date'}',
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
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'verified'
              ? '${user.fullName} has been approved.'
              : '${user.fullName}\'s registration was rejected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;
    final visible = _visible;

    final Widget content;
    if (_isLoading) {
      content = Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: p.accentLabel,
          ),
        ),
      );
    } else if (_loadError != null) {
      content = AdminErrorBox(message: _loadError!, onRetry: _load);
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide)
            const AdminTableHeader(
              labels: [
                'Name',
                'Email',
                'ID type',
                'Registered',
                'Status',
                'Action',
              ],
              flex: _flex,
            ),
          if (visible.isEmpty)
            const AdminEmptyState(
              icon: Icons.how_to_reg_outlined,
              title: 'No matching registrations',
              hint: 'Try a different filter, or check back once new users register.',
            )
          else
            for (final user in visible)
              _RegistrationRow(
                user: user,
                isWide: isWide,
                flex: _flex,
                onReview: () => _review(user),
              ),
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Showing ${visible.length} of ${_users.length} registrations',
              style: orgText(p, size: 12, color: p.textSecondary),
            ),
          ),
        ],
      );
    }

    return AdminShell(
      active: AdminNavItem.userRegistrations,
      title: 'User Registrations',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'User Registrations',
            subtitle:
                'Review the ID and selfie of new eventgoers before their accounts are activated.',
            actions: [
              AdminIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh data',
                loading: _isLoading,
                onPressed: _isLoading ? null : _load,
              ),
            ],
          ),
          const SizedBox(height: 24),
          AdminFilterChips(
            labels: _filters,
            selected: _filters.indexOf(_filter),
            counts: [
              for (final f in _filters)
                _isLoading || _loadError != null ? null : _countFor(f),
            ],
            onSelected: (i) => setState(() => _filter = _filters[i]),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: AdminSearchField(
              hint: 'Search name or email',
              width: isWide ? 320 : 260,
              onChanged: (v) => setState(() => _search = v),
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
      ),
    );
  }
}

class _RegistrationRow extends StatelessWidget {
  const _RegistrationRow({
    required this.user,
    required this.isWide,
    required this.flex,
    required this.onReview,
  });

  final AdminUserSummary user;
  final bool isWide;
  final List<int> flex;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final stage = _stageOf(user);
    final registered = _registeredOn(user);
    final idType = user.idType?.trim().isNotEmpty == true
        ? user.idType!
        : '\u2014';

    final action = AdminRowAction(
      label: stage == _Stage.pending ? 'Review' : 'View',
      filled: stage == _Stage.pending,
      // Nothing to look at until an ID has been uploaded.
      onPressed: stage == _Stage.incomplete ? null : onReview,
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
                _stageBadge(stage),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ID: $idType \u2022 Registered $registered',
              style: orgText(p, size: 12, color: p.textSecondary),
            ),
            const SizedBox(height: 12),
            action,
          ],
        ),
      );
    }

    return AdminTableRow(
      children: [
        adminCell(context, flex[0], user.fullName, bold: true),
        adminCell(context, flex[1], user.email),
        adminCell(context, flex[2], idType),
        adminCell(context, flex[3], registered, muted: true),
        Expanded(
          flex: flex[4],
          child: Align(
            alignment: Alignment.centerLeft,
            child: _stageBadge(stage),
          ),
        ),
        Expanded(
          flex: flex[5],
          child: Align(alignment: Alignment.centerLeft, child: action),
        ),
      ],
    );
  }
}
