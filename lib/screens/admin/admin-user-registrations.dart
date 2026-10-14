import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_document_viewer.dart';
import '../../widgets/admin_shell.dart';
import '../organizer/app_colors.dart';

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

class _AdminUserRegistrationsScreenState
    extends State<AdminUserRegistrationsScreen> {
  static const _filters = ['Pending', 'Approved', 'Rejected', 'Incomplete', 'All'];

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

  int _countFor(String filter) => _users.where((u) => _matches(u, filter)).length;

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
          '${user.email} \u2022 Registered ${user.createdAt != null ? formatFriendlyDate(user.createdAt!) : 'unknown date'}',
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
    final isWide = MediaQuery.of(context).size.width >= 900;
    final visible = _visible;
    return AdminShell(
      active: AdminNavItem.userRegistrations,
      title: 'User Registrations',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('User Registrations', style: AppTextStyles.h2),
              ),
              IconButton(
                onPressed: _isLoading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Review the ID and selfie of new eventgoers before their accounts are activated.',
            style: TextStyle(color: AppColors.textGray, fontSize: 10),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final filter in _filters)
                ChoiceChip(
                  label: Text(
                    _isLoading ? filter : '$filter (${_countFor(filter)})',
                  ),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: _filter == filter ? Colors.white : AppColors.textGray,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: AppColors.primaryPurple,
                  backgroundColor: const Color(0xFFF0EEFA),
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
              SizedBox(
                width: isWide ? 240 : 180,
                height: 32,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Search name or email',
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
            ],
          ),
          const SizedBox(height: 18),
          Container(
            constraints: const BoxConstraints(minHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                : _loadError != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              _loadError!,
                              style: const TextStyle(
                                color: AppColors.dangerRed,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          if (isWide) const _TableHeader(),
                          if (visible.isEmpty)
                            const _EmptyState()
                          else
                            for (final user in visible)
                              _RegistrationRow(
                                user: user,
                                isWide: isWide,
                                onReview: () => _review(user),
                              ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Showing ${visible.length} of ${_users.length} registrations',
                                style: const TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 10,
                                ),
                              ),
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

const _headerStyle = TextStyle(
  color: AppColors.textGray,
  fontSize: 9,
  fontWeight: FontWeight.w700,
);

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFFFBFBFD),
        child: const Row(
          children: [
            Expanded(flex: 2, child: Text('NAME', style: _headerStyle)),
            Expanded(flex: 2, child: Text('EMAIL', style: _headerStyle)),
            Expanded(child: Text('ID TYPE', style: _headerStyle)),
            Expanded(child: Text('REGISTERED', style: _headerStyle)),
            Expanded(child: Text('STATUS', style: _headerStyle)),
            SizedBox(width: 90, child: Text('ACTION', style: _headerStyle)),
          ],
        ),
      ),
      const Divider(height: 1),
    ],
  );
}

class _RegistrationRow extends StatelessWidget {
  const _RegistrationRow({
    required this.user,
    required this.isWide,
    required this.onReview,
  });

  final AdminUserSummary user;
  final bool isWide;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final stage = _stageOf(user);
    final registered = user.createdAt != null
        ? formatFriendlyDate(user.createdAt!)
        : '\u2014';
    final idType = user.idType?.trim().isNotEmpty == true ? user.idType! : '\u2014';

    final action = TextButton(
      // Nothing to look at until an ID has been uploaded.
      onPressed: stage == _Stage.incomplete ? null : onReview,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        alignment: Alignment.centerLeft,
      ),
      child: Text(
        stage == _Stage.pending ? 'Review' : 'View',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );

    if (!isWide) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderLight)),
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
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                _StageBadge(stage: stage),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ID: $idType \u2022 Registered $registered',
              style: const TextStyle(fontSize: 10, color: AppColors.textGray),
            ),
            const SizedBox(height: 6),
            action,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              user.fullName,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user.email,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              idType,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              registered,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textGray),
            ),
          ),
          Expanded(child: _StageBadge(stage: stage)),
          SizedBox(width: 90, child: action),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});
  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (stage) {
      _Stage.approved => (
        'Approved',
        AppColors.successGreen,
        AppColors.successGreenBg,
      ),
      _Stage.rejected => (
        'Rejected',
        AppColors.dangerRed,
        AppColors.dangerRedBg,
      ),
      _Stage.incomplete => (
        'Incomplete',
        AppColors.textGray,
        const Color(0xFFF3F4F6),
      ),
      _Stage.pending => (
        'Pending',
        AppColors.warningOrange,
        AppColors.warningOrangeBg,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_reg_outlined, size: 34, color: Color(0xFFD9D7E4)),
          SizedBox(height: 10),
          Text(
            'No matching registrations',
            style: TextStyle(color: AppColors.textGray, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            'Try a different filter, or check back once new users register.',
            style: TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
          ),
        ],
      ),
    ),
  );
}
