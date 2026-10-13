import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../services/admin_overview_service.dart';
import '../../services/admin_refund_service.dart';
import '../../services/admin_resale_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/csv_export.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../organizer/app_colors.dart';
import 'admin-announcement.dart';
import 'admin-fraud-alerts.dart';
import 'admin-organizer-applications.dart';
import 'admin-route.dart';

typedef _ActivityItem = ({DateTime at, IconData icon, String text});

/// The admin landing page: headline numbers, what needs attention (pending
/// organizer applications, open fraud alerts) and a recent-activity feed.
///
/// Each section loads on its own, so one failing (for example because a SQL
/// file hasn't been run yet) only shows an error in that section instead of
/// blanking the whole page.
///
/// The activity feed is built from real records (new registrations, fraud
/// alerts, refunds), newest first. It is not a separate audit log: actions
/// like "admin approved an organizer" are not recorded anywhere yet.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DashboardStats? _stats;
  String? _statsError;

  List<AdminUserSummary> _users = const [];
  String? _usersError;

  List<FraudAlertEntry> _alerts = const [];
  String? _alertsError;

  List<RefundEntry> _refunds = const [];
  String? _refundsError;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadStats(), _loadUsers(), _loadAlerts(), _loadRefunds()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      final stats = await AdminOverviewService.instance.fetchDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsError = null;
      });
    } on AdminOverviewException catch (e) {
      if (!mounted) return;
      setState(() => _statsError = e.message);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await AdminUserService.instance.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _usersError = null;
      });
    } on AdminUserServiceException catch (e) {
      if (!mounted) return;
      setState(() => _usersError = e.message);
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await AdminResaleService.instance.fetchAlerts();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _alertsError = null;
      });
    } on AdminResaleException catch (e) {
      if (!mounted) return;
      setState(() => _alertsError = e.message);
    }
  }

  Future<void> _loadRefunds() async {
    try {
      final refunds = await AdminRefundService.instance.fetchRefunds();
      if (!mounted) return;
      setState(() {
        _refunds = refunds;
        _refundsError = null;
      });
    } on AdminRefundException catch (e) {
      if (!mounted) return;
      setState(() => _refundsError = e.message);
    }
  }

  List<AdminUserSummary> get _pendingApplications => _users
      .where((u) => u.role == 'organizer' && u.idVerificationStatus == 'pending')
      .toList();

  List<FraudAlertEntry> get _openAlerts => _alerts.where((a) => !a.isClosed).toList();

  static String _roleLabel(String role) => switch (role) {
    'organizer' => 'an organizer',
    'admin' => 'an admin',
    _ => 'an eventgoer',
  };

  List<_ActivityItem> get _activity {
    final items = <_ActivityItem>[];
    for (final u in _users) {
      final at = u.createdAt;
      if (at == null) continue;
      items.add((
        at: at.toLocal(),
        icon: u.role == 'organizer' ? Icons.business_outlined : Icons.person_add_alt_outlined,
        text: '${u.fullName} registered as ${_roleLabel(u.role)}',
      ));
    }
    for (final a in _alerts) {
      items.add((
        at: a.createdAt,
        icon: Icons.flag_outlined,
        text: 'Fraud alert (${a.typeLabel}) for ${a.userName ?? 'an unknown user'}',
      ));
    }
    for (final r in _refunds) {
      items.add((
        at: r.createdAt,
        icon: Icons.assignment_return_outlined,
        text:
            'Refund of ${formatPeso(r.amount)} to ${r.buyerName} for ${r.eventTitle} (${r.statusLabel.toLowerCase()})',
      ));
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return items.take(10).toList();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportActivity() async {
    final items = _activity;
    if (items.isEmpty) {
      _toast('There is no activity to export yet.');
      return;
    }
    final csv = toCsv([
      ['When', 'Activity'],
      for (final item in items) [item.at.toIso8601String(), csvSafe(item.text)],
    ]);
    final saved = await saveCsvFile(
      fileName: 'fairtix-activity-${formatIsoDate(DateTime.now())}.csv',
      csv: csv,
    );
    _toast(saved ? 'Activity exported.' : 'Export canceled.');
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      active: AdminNavItem.dashboard,
      title: 'Dashboard',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final stats = _stats;
    String count(int? n) => n == null ? '\u2014' : '$n';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Dashboard', style: AppTextStyles.h2)),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAnnouncementScreen()),
              ),
              icon: const Icon(Icons.campaign_outlined, size: 14),
              label: const Text('Create Announcement', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(_isLoading ? 'Refreshing...' : 'Refresh Data', style: const TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_statsError != null) ...[
          AdminCard(child: AdminErrorBox(message: _statsError!, onRetry: _loadStats)),
          const SizedBox(height: 18),
        ],
        AdminSummaryRow(
          cards: [
            AdminSummaryCard(
              icon: Icons.people_outline,
              color: AppColors.primaryPurple,
              label: 'Total Users',
              value: count(stats?.totalUsers),
              caption: 'Eventgoer accounts',
            ),
            AdminSummaryCard(
              icon: Icons.business_outlined,
              color: AppColors.primaryPurple,
              label: 'Total Organizers',
              value: count(stats?.totalOrganizers),
              caption: '${_pendingApplications.length} awaiting approval',
            ),
            AdminSummaryCard(
              icon: Icons.calendar_today_outlined,
              color: AppColors.primaryPurple,
              label: 'Total Events',
              value: count(stats?.totalEvents),
              caption: 'Multi-day runs count once',
            ),
            AdminSummaryCard(
              icon: Icons.confirmation_number_outlined,
              color: AppColors.primaryPurple,
              label: 'Tickets Sold',
              value: count(stats?.ticketsSold),
              caption: 'Excludes refunded tickets',
            ),
            AdminSummaryCard(
              icon: Icons.monetization_on_outlined,
              color: AppColors.successGreen,
              label: 'Platform Revenue',
              value: stats == null ? '\u2014' : formatPeso(stats.platformRevenue),
              caption: 'Platform fees, after refunds',
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth > 760;
            final applications = _buildApplicationsPanel();
            final alerts = _buildAlertsPanel();
            return sideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: applications),
                      const SizedBox(width: 16),
                      Expanded(child: alerts),
                    ],
                  )
                : Column(children: [applications, const SizedBox(height: 16), alerts]);
          },
        ),
        const SizedBox(height: 18),
        _buildActivityPanel(),
      ],
    );
  }

  Widget _panel({
    required String title,
    required String action,
    required VoidCallback onAction,
    required Widget child,
    bool alertAction = false,
  }) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontSize: 12))),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  foregroundColor: alertAction ? AppColors.dangerRed : AppColors.primaryPurple,
                ),
                child: Text(action, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Divider(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _inlineMessage(String text, {bool error = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: error ? AppColors.dangerRed : AppColors.textGray, fontSize: 11),
      ),
    ),
  );

  Widget _buildApplicationsPanel() {
    final pending = _pendingApplications;
    final Widget body;
    if (_usersError != null) {
      body = _inlineMessage(_usersError!, error: true);
    } else if (_isLoading && _users.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    } else if (pending.isEmpty) {
      body = _inlineMessage('No applications waiting for review.');
    } else {
      body = Column(
        children: [
          for (final applicant in pending.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (applicant.organizationName?.trim().isNotEmpty ?? false)
                              ? applicant.organizationName!
                              : applicant.fullName,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${applicant.fullName} \u2022 ${applicant.email}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                        ),
                      ],
                    ),
                  ),
                  if (applicant.createdAt != null)
                    Text(
                      formatAdminDate(applicant.createdAt!.toLocal()),
                      style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                    ),
                ],
              ),
            ),
          if (pending.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                '+ ${pending.length - 5} more',
                style: const TextStyle(fontSize: 10, color: AppColors.textGray),
              ),
            ),
        ],
      );
    }
    return _panel(
      title: 'Pending Organizer Applications${pending.isEmpty ? '' : ' (${pending.length})'}',
      action: 'View All',
      onAction: () => Navigator.pushReplacement(
        context,
        adminPageRoute(const AdminOrganizerApplicationsScreen()),
      ),
      child: body,
    );
  }

  Widget _buildAlertsPanel() {
    final open = _openAlerts;
    final Widget body;
    if (_alertsError != null) {
      body = _inlineMessage(_alertsError!, error: true);
    } else if (_isLoading && _alerts.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    } else if (open.isEmpty) {
      body = _inlineMessage('No open fraud alerts.');
    } else {
      body = Column(
        children: [
          for (final alert in open.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert.typeLabel, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        Text(
                          '${alert.userName ?? 'Unknown user'} \u2022 ${formatAdminDateTime(alert.createdAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                        ),
                      ],
                    ),
                  ),
                  switch (alert.severity) {
                    'high' => AdminBadge.danger(alert.severityLabel),
                    'low' => AdminBadge.neutral(alert.severityLabel),
                    _ => AdminBadge.warning(alert.severityLabel),
                  },
                ],
              ),
            ),
          if (open.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                '+ ${open.length - 5} more',
                style: const TextStyle(fontSize: 10, color: AppColors.textGray),
              ),
            ),
        ],
      );
    }
    return _panel(
      title: 'Recent Fraud Alerts${open.isEmpty ? '' : ' (${open.length} open)'}',
      action: 'View All',
      alertAction: true,
      onAction: () => Navigator.pushReplacement(
        context,
        adminPageRoute(const AdminFraudAlertsScreen()),
      ),
      child: body,
    );
  }

  Widget _buildActivityPanel() {
    final items = _activity;
    final failed = [_usersError, _alertsError, _refundsError].whereType<String>().isNotEmpty;
    final Widget body;
    if (_isLoading && items.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(26),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    } else if (items.isEmpty) {
      body = _inlineMessage(
        failed
            ? 'Some activity could not be loaded. Use Refresh Data to try again.'
            : 'No recent activity yet.',
      );
    } else {
      body = Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: const Color(0xFFF0E9FF),
                    child: Icon(item.icon, size: 14, color: AppColors.primaryPurple),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.text, style: const TextStyle(fontSize: 11.5))),
                  const SizedBox(width: 10),
                  Text(
                    formatAdminDateTime(item.at),
                    style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 6),
            child: Text(
              'Built from recent registrations, fraud alerts and refunds. Admin actions are not logged yet.',
              style: TextStyle(fontSize: 9.5, color: Color(0xFFA6A9B7)),
            ),
          ),
        ],
      );
    }

    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Recent Activity', style: AppTextStyles.label)),
              IconButton(
                onPressed: _exportActivity,
                icon: const Icon(Icons.download_outlined, size: 16),
                tooltip: 'Export activity',
              ),
            ],
          ),
          const Divider(),
          body,
        ],
      ),
    );
  }
}
