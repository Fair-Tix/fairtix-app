import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../services/admin_user_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_document_viewer.dart'
    show AdminReviewDocument, showAdminReviewDialog;
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';

/// Organizer applications ("Proof of Venue Booking" + "Valid Event
/// Permit" review). Reads/writes `public.users` where `role = 'organizer'`
/// via [AdminUserService] — approving/rejecting here sets the same
/// `id_verification_status` column the eventgoer ID review uses (see
/// supabase/schema.sql, Table 6), just for organizer accounts instead of
/// buyer accounts.
class AdminOrganizerApplicationsScreen extends StatefulWidget {
  const AdminOrganizerApplicationsScreen({super.key});

  @override
  State<AdminOrganizerApplicationsScreen> createState() =>
      _AdminOrganizerApplicationsScreenState();
}

class _AdminOrganizerApplicationsScreenState
    extends State<AdminOrganizerApplicationsScreen> {
  static const _filters = ['All', 'Pending', 'Approved', 'Rejected'];

  /// Relative column widths of the wide table (name, email, organization,
  /// submitted, action, status). Header and rows share these.
  static const _flex = [3, 4, 3, 2, 2, 2];

  int _filterIndex = 1; // defaults to "Pending" — the actionable queue

  List<AdminUserSummary> _applications = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final users = await AdminUserService.instance.fetchUsers(
        role: 'organizer',
      );
      if (!mounted) return;
      setState(() {
        _applications = users;
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

  static String? _statusFor(int filterIndex) => switch (filterIndex) {
    1 => 'pending',
    2 => 'verified',
    3 => 'rejected',
    _ => null,
  };

  List<AdminUserSummary> get _filtered {
    final filterStatus = _statusFor(_filterIndex);
    if (filterStatus == null) return _applications;
    return _applications
        .where((a) => a.idVerificationStatus == filterStatus)
        .toList();
  }

  int _countFor(int filterIndex) {
    final status = _statusFor(filterIndex);
    if (status == null) return _applications.length;
    return _applications.where((a) => a.idVerificationStatus == status).length;
  }

  static String _displayName(AdminUserSummary a) =>
      a.organizationName?.trim().isNotEmpty == true
      ? a.organizationName!
      : a.fullName;

  static String _appliedOn(AdminUserSummary a) =>
      a.createdAt != null ? formatAdminDate(a.createdAt!.toLocal()) : '\u2014';

  Future<void> _reviewApplication(AdminUserSummary applicant) async {
    await showAdminReviewDialog(
      context: context,
      title: _displayName(applicant),
      subtitle:
          '${applicant.fullName} \u2022 Applied ${applicant.createdAt != null ? _appliedOn(applicant) : 'unknown date'}',
      currentStatus: applicant.idVerificationStatus,
      documents: [
        AdminReviewDocument(
          label: 'Proof of Venue Booking',
          bucket: 'organizer_docs',
          path: applicant.venueProofUrl,
        ),
        AdminReviewDocument(
          label: 'Valid Event Permit',
          bucket: 'organizer_docs',
          path: applicant.eventPermitUrl,
        ),
      ],
      onApprove: () => _decide(applicant, 'verified'),
      onReject: () => _decide(applicant, 'rejected'),
    );
  }

  Future<void> _decide(AdminUserSummary applicant, String status) async {
    await AdminUserService.instance.setIdVerificationStatus(
      userId: applicant.id,
      status: status,
    );
    await _loadApplications();
    if (!mounted) return;
    final label = _displayName(applicant);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'verified'
              ? '$label has been approved.'
              : '$label\'s application was rejected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return AdminShell(
      active: AdminNavItem.organizerApplications,
      title: 'Applications',
      body: _buildContent(isWide),
    );
  }

  Widget _buildContent(bool isWide) {
    final p = FairTixPalette.of(context);
    final filtered = _filtered;
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
      content = AdminErrorBox(
        message: _loadError!,
        onRetry: _loadApplications,
      );
    } else if (isWide) {
      content = _buildWideTable(filtered);
    } else {
      content = _buildCompactList(filtered);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Organizer Applications',
          subtitle:
              'Review venue bookings and event permits before organizers can publish events.',
          actions: [
            AdminIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh data',
              loading: _isLoading,
              onPressed: _isLoading ? null : _loadApplications,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminFilterChips(
          labels: _filters,
          selected: _filterIndex,
          counts: [
            for (var i = 0; i < _filters.length; i++)
              _isLoading || _loadError != null ? null : _countFor(i),
          ],
          onSelected: (i) => setState(() => _filterIndex = i),
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

  Widget _buildWideTable(List<AdminUserSummary> filtered) {
    final p = FairTixPalette.of(context);
    const headers = [
      'APPLICANT',
      'EMAIL',
      'ORGANIZATION',
      'SUBMITTED',
      'DOCUMENTS',
      'STATUS',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: p.progressTrack,
          child: Row(
            children: [
              for (var i = 0; i < headers.length; i++)
                Expanded(
                  flex: _flex[i],
                  child: Text(
                    headers[i],
                    style: orgText(
                      p,
                      size: 11,
                      weight: FontWeight.w700,
                      color: p.textSecondary,
                      letterSpacing: 0.6,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (filtered.isEmpty)
          const _EmptyApplications()
        else
          for (final applicant in filtered)
            _ApplicationRowWide(
              applicant: applicant,
              flex: _flex,
              onReview: applicant.canReview
                  ? () => _reviewApplication(applicant)
                  : null,
            ),
        Divider(height: 1, color: p.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'Showing ${filtered.length} of ${_applications.length} applications',
            style: orgText(p, size: 12, color: p.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactList(List<AdminUserSummary> filtered) {
    if (filtered.isEmpty) return const _EmptyApplications();
    return Column(
      children: [
        for (final applicant in filtered)
          _ApplicationRowCompact(
            applicant: applicant,
            onReview: applicant.canReview
                ? () => _reviewApplication(applicant)
                : null,
          ),
      ],
    );
  }
}

AdminBadge _statusBadge(String status) => switch (status) {
  'verified' => AdminBadge.success('Approved'),
  'rejected' => AdminBadge.danger('Rejected'),
  _ => AdminBadge.warning('Pending'),
};

class _ApplicationRowWide extends StatelessWidget {
  const _ApplicationRowWide({
    required this.applicant,
    required this.flex,
    required this.onReview,
  });

  final AdminUserSummary applicant;
  final List<int> flex;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final pending = applicant.idVerificationStatus == 'pending';
    final org = applicant.organizationName?.trim().isNotEmpty == true
        ? applicant.organizationName!
        : '\u2014';
    final submitted = _AdminOrganizerApplicationsScreenState._appliedOn(
      applicant,
    );

    Widget cell(int i, String text, {bool bold = false, bool muted = false}) =>
        Expanded(
          flex: flex[i],
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: orgText(
                p,
                size: bold ? 14 : 13,
                weight: bold ? FontWeight.w700 : FontWeight.w400,
                color: muted ? p.textSecondary : p.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          cell(0, applicant.fullName, bold: true),
          cell(1, applicant.email),
          cell(2, org),
          cell(3, submitted, muted: true),
          Expanded(
            flex: flex[4],
            child: Align(
              alignment: Alignment.centerLeft,
              child: AdminRowAction(
                label: pending ? 'Review' : 'View',
                filled: pending,
                onPressed: onReview,
              ),
            ),
          ),
          Expanded(
            flex: flex[5],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge(applicant.idVerificationStatus),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationRowCompact extends StatelessWidget {
  const _ApplicationRowCompact({
    required this.applicant,
    required this.onReview,
  });

  final AdminUserSummary applicant;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final pending = applicant.idVerificationStatus == 'pending';
    final submitted = _AdminOrganizerApplicationsScreenState._appliedOn(
      applicant,
    );
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
                      applicant.fullName,
                      style: orgText(p, size: 15, weight: FontWeight.w700),
                    ),
                    Text(
                      applicant.email,
                      overflow: TextOverflow.ellipsis,
                      style: orgText(p, size: 13, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(applicant.idVerificationStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            applicant.organizationName?.trim().isNotEmpty == true
                ? applicant.organizationName!
                : 'No organization on file',
            style: orgText(p, size: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'Applied $submitted',
            style: orgText(p, size: 12, color: p.textSecondary),
          ),
          const SizedBox(height: 12),
          AdminRowAction(
            label: pending ? 'Review Application' : 'View Documents',
            filled: pending,
            onPressed: onReview,
          ),
        ],
      ),
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications();

  @override
  Widget build(BuildContext context) => const AdminEmptyState(
    icon: Icons.inbox_outlined,
    title: 'No matching applications',
    hint: 'Try a different filter or check back once organizers apply.',
  );
}
