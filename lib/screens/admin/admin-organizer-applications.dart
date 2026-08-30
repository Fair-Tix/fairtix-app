import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../services/admin_session.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_document_viewer.dart';
import '../organizer/app_colors.dart';
import 'admin-dashboard.dart';
import 'admin-login.dart';
import 'admin-route.dart';
import 'admin-accounts.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-resale-monitoring.dart';
import 'admin-revenue-reports.dart';
import 'admin-platform-settings.dart';
import 'admin-profile.dart';

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
      final users = await AdminUserService.instance.fetchUsers(role: 'organizer');
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

  List<AdminUserSummary> get _filtered {
    final filterStatus = switch (_filterIndex) {
      1 => 'pending',
      2 => 'verified',
      3 => 'rejected',
      _ => null,
    };
    if (filterStatus == null) return _applications;
    return _applications.where((a) => a.idVerificationStatus == filterStatus).toList();
  }

  Future<void> _reviewApplication(AdminUserSummary applicant) async {
    await showAdminReviewDialog(
      context: context,
      title: applicant.organizationName?.trim().isNotEmpty == true
          ? applicant.organizationName!
          : applicant.fullName,
      subtitle:
          '${applicant.fullName} \u2022 Applied ${applicant.createdAt != null ? formatFriendlyDate(applicant.createdAt!) : 'unknown date'}',
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
    final label = applicant.organizationName?.trim().isNotEmpty == true
        ? applicant.organizationName!
        : applicant.fullName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'verified' ? '$label has been approved.' : '$label\'s application was rejected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
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
    final currentEmail = AdminSession.instance.currentEmail ?? 'admin@fairtix.com';
    final items = [
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
                selected: index == 1,
                onTap: () {
                  final pages = <int, Widget>{
                    0: const AdminDashboardScreen(),
                    2: const AdminAccountsScreen(),
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
                },
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
                        Text(currentEmail, style: const TextStyle(color: AppColors.textGray, fontSize: 9)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _confirmLogout,
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
          Text('Organizer Applications', style: AppTextStyles.label),
          const Spacer(),
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

  Widget _buildContent(bool isWide) {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Organizer Applications', style: AppTextStyles.h2)),
            IconButton(
              onPressed: _isLoading ? null : _loadApplications,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (var index = 0; index < _filters.length; index++)
              ChoiceChip(
                label: Text(_filters[index]),
                selected: _filterIndex == index,
                onSelected: (_) => setState(() => _filterIndex = index),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: _filterIndex == index ? Colors.white : AppColors.textGray,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: AppColors.primaryPurple,
                backgroundColor: const Color(0xFFF0EEFA),
                side: BorderSide.none,
                showCheckmark: false,
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
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              : _loadError != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(_loadError!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 12)),
                          const SizedBox(height: 10),
                          OutlinedButton(onPressed: _loadApplications, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : isWide
                      ? _buildWideTable(filtered)
                      : _buildCompactList(filtered),
        ),
      ],
    );
  }

  Widget _buildWideTable(List<AdminUserSummary> filtered) {
    const headers = ['Applicant Name', 'Email', 'Organization', 'Submitted', 'Documents', 'Status', ''];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFFBFBFD),
          child: Row(
            children: [
              for (final header in headers) Expanded(child: Text(header, style: _headerStyle)),
            ],
          ),
        ),
        const Divider(height: 1),
        if (filtered.isEmpty)
          const _EmptyApplications()
        else
          for (final applicant in filtered) _ApplicationRowWide(applicant: applicant, screen: this),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Showing ${filtered.length} of ${_applications.length} applications',
            style: const TextStyle(color: AppColors.textGray, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactList(List<AdminUserSummary> filtered) {
    if (filtered.isEmpty) {
      return const Padding(padding: EdgeInsets.all(18), child: _EmptyApplications());
    }
    return Column(
      children: [for (final applicant in filtered) _ApplicationRowCompact(applicant: applicant, screen: this)],
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
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
    if (!mounted || shouldLogout != true) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }
}

const _headerStyle = TextStyle(color: AppColors.textGray, fontSize: 9, fontWeight: FontWeight.w700);

class _ApplicationStatusBadge extends StatelessWidget {
  const _ApplicationStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'verified' => ('Approved', AppColors.successGreen, AppColors.successGreenBg),
      'rejected' => ('Rejected', AppColors.dangerRed, AppColors.dangerRedBg),
      _ => ('Pending', AppColors.warningOrange, AppColors.warningOrangeBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ApplicationRowWide extends StatelessWidget {
  const _ApplicationRowWide({required this.applicant, required this.screen});
  final AdminUserSummary applicant;
  final _AdminOrganizerApplicationsScreenState screen;

  @override
  Widget build(BuildContext context) {
    final submitted = applicant.createdAt != null ? formatFriendlyDate(applicant.createdAt!) : '\u2014';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
      child: Row(
        children: [
          Expanded(child: Text(applicant.fullName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
          Expanded(child: Text(applicant.email, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          Expanded(
            child: Text(
              applicant.organizationName?.trim().isNotEmpty == true ? applicant.organizationName! : '\u2014',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: Text(submitted, style: const TextStyle(fontSize: 10.5, color: AppColors.textGray))),
          Expanded(
            child: TextButton(
              onPressed: applicant.hasReviewableDocuments ? () => screen._reviewApplication(applicant) : null,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, alignment: Alignment.centerLeft),
              child: Text(
                applicant.idVerificationStatus == 'pending' ? 'Review' : 'View',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(child: _ApplicationStatusBadge(status: applicant.idVerificationStatus)),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _ApplicationRowCompact extends StatelessWidget {
  const _ApplicationRowCompact({required this.applicant, required this.screen});
  final AdminUserSummary applicant;
  final _AdminOrganizerApplicationsScreenState screen;

  @override
  Widget build(BuildContext context) {
    final submitted = applicant.createdAt != null ? formatFriendlyDate(applicant.createdAt!) : '\u2014';
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
                    Text(applicant.fullName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Text(applicant.email, style: const TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                  ],
                ),
              ),
              _ApplicationStatusBadge(status: applicant.idVerificationStatus),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            applicant.organizationName?.trim().isNotEmpty == true ? applicant.organizationName! : 'No organization on file',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text('Applied $submitted', style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: applicant.hasReviewableDocuments ? () => screen._reviewApplication(applicant) : null,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, alignment: Alignment.centerLeft),
            child: Text(
              applicant.idVerificationStatus == 'pending' ? 'Review Application' : 'View Documents',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 34, color: Color(0xFFD9D7E4)),
              SizedBox(height: 10),
              Text('No matching applications', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
              SizedBox(height: 4),
              Text(
                'Try a different filter or check back once organizers apply.',
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
