import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../services/admin_overview_service.dart';
import '../../services/admin_refund_service.dart';
import '../../services/admin_resale_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/csv_export.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/ft_skeleton.dart';
import '../../widgets/organizer_ui.dart';
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
    await Future.wait([
      _loadStats(),
      _loadUsers(),
      _loadAlerts(),
      _loadRefunds(),
    ]);
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
      .where(
        (u) => u.role == 'organizer' && u.idVerificationStatus == 'pending',
      )
      .toList();

  List<FraudAlertEntry> get _openAlerts =>
      _alerts.where((a) => !a.isClosed).toList();

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
        icon: u.role == 'organizer'
            ? Icons.business_outlined
            : Icons.person_add_alt_outlined,
        text: '${u.fullName} registered as ${_roleLabel(u.role)}',
      ));
    }
    for (final a in _alerts) {
      items.add((
        at: a.createdAt,
        icon: Icons.flag_outlined,
        text:
            'Fraud alert (${a.typeLabel}) for ${a.userName ?? 'an unknown user'}',
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final palette = FairTixPalette.of(context);
    final stats = _stats;
    String count(int? n) => n == null ? '\u2014' : '$n';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Dashboard',
          subtitle: 'Platform overview and the items that need your attention.',
          actions: [
            // One centered row so the icon button and the primary button line up
            // with each other and with the title, at every width.
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AdminIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh data',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _load,
                ),
                const SizedBox(width: 10),
                AdminHeaderButton(
                  icon: Icons.campaign_outlined,
                  label: 'Create Announcement',
                  filled: true,
                  onPressed: () => showAdminAnnouncementDialog(context),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_statsError != null) ...[
          AdminCard(
            child: AdminErrorBox(message: _statsError!, onRetry: _loadStats),
          ),
          const SizedBox(height: 20),
        ],
        if (_isLoading && stats == null && _statsError == null)
          const FtShimmer(child: AdminSkeletonSummaryRow(count: 5))
        else
        AdminSummaryRow(
          cards: [
            AdminSummaryCard(
              icon: Icons.people_outline,
              color: palette.accentLabel,
              label: 'Total Users',
              value: count(stats?.totalUsers),
              caption: 'Eventgoer accounts',
            ),
            AdminSummaryCard(
              icon: Icons.business_outlined,
              color: palette.accentLabel,
              label: 'Total Organizers',
              value: count(stats?.totalOrganizers),
              caption: '${_pendingApplications.length} awaiting approval',
            ),
            AdminSummaryCard(
              icon: Icons.calendar_today_outlined,
              color: palette.accentLabel,
              label: 'Total Events',
              value: count(stats?.totalEvents),
              caption: 'Multi-day runs count once',
            ),
            AdminSummaryCard(
              icon: Icons.confirmation_number_outlined,
              color: palette.accentLabel,
              label: 'Tickets Sold',
              value: count(stats?.ticketsSold),
              caption: 'Excludes refunded tickets',
            ),
            AdminSummaryCard(
              icon: Icons.monetization_on_outlined,
              color: palette.success,
              label: 'Platform Revenue',
              value: stats == null
                  ? '\u2014'
                  : formatPeso(stats.platformRevenue),
              caption: 'Platform fees, after refunds',
            ),
          ],
        ),
        const SizedBox(height: 20),
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
                      const SizedBox(width: 20),
                      Expanded(child: alerts),
                    ],
                  )
                : Column(
                    children: [
                      applications,
                      const SizedBox(height: 20),
                      alerts,
                    ],
                  );
          },
        ),
        const SizedBox(height: 20),
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
    final p = FairTixPalette.of(context);
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: orgText(p, size: 16, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAction,
                  child: Text(
                    action,
                    style: orgText(
                      p,
                      size: 13,
                      weight: FontWeight.w700,
                      color: alertAction ? p.danger : p.accentLabel,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: p.border),
          child,
        ],
      ),
    );
  }

  Widget _inlineMessage(String text, {bool error = false}) {
    final p = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: orgText(
            p,
            size: 13,
            color: error ? p.danger : p.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Skeleton rows for a panel that is still loading its first data: two
  /// text lines and a trailing value, with a round icon in front when
  /// [leadingCircle] is set (the activity feed).
  Widget _spinner({bool leadingCircle = false, int rows = 3}) {
    return FtShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  if (leadingCircle) ...[
                    const FtSkeletonCircle(size: 34),
                    const SizedBox(width: 12),
                  ],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FtSkeletonBox(width: 170, height: 14),
                        SizedBox(height: 6),
                        FtSkeletonBox(width: 230, height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const FtSkeletonBox(width: 64, height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _moreLabel(int more) {
    final p = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        '+ $more more',
        style: orgText(p, size: 12, color: p.textSecondary),
      ),
    );
  }

  Widget _buildApplicationsPanel() {
    final p = FairTixPalette.of(context);
    final pending = _pendingApplications;
    final Widget body;
    if (_usersError != null) {
      body = _inlineMessage(_usersError!, error: true);
    } else if (_isLoading && _users.isEmpty) {
      body = _spinner();
    } else if (pending.isEmpty) {
      body = _inlineMessage('No applications waiting for review.');
    } else {
      body = Column(
        children: [
          for (final applicant in pending.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (applicant.organizationName?.trim().isNotEmpty ??
                                  false)
                              ? applicant.organizationName!
                              : applicant.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: orgText(p, size: 14, weight: FontWeight.w700),
                        ),
                        Text(
                          '${applicant.fullName} \u2022 ${applicant.email}',
                          overflow: TextOverflow.ellipsis,
                          style: orgText(p, size: 12, color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (applicant.createdAt != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      formatAdminDate(applicant.createdAt!.toLocal()),
                      style: orgText(p, size: 12, color: p.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          if (pending.length > 5) _moreLabel(pending.length - 5),
        ],
      );
    }
    return _panel(
      title:
          'Pending Organizer Applications${pending.isEmpty ? '' : ' (${pending.length})'}',
      action: 'View All',
      onAction: () => adminPushReplacement(
        context,
        const AdminOrganizerApplicationsScreen(),
      ),
      child: body,
    );
  }

  Widget _buildAlertsPanel() {
    final p = FairTixPalette.of(context);
    final open = _openAlerts;
    final Widget body;
    if (_alertsError != null) {
      body = _inlineMessage(_alertsError!, error: true);
    } else if (_isLoading && _alerts.isEmpty) {
      body = _spinner();
    } else if (open.isEmpty) {
      body = _inlineMessage('No open fraud alerts.');
    } else {
      body = Column(
        children: [
          for (final alert in open.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.typeLabel,
                          overflow: TextOverflow.ellipsis,
                          style: orgText(p, size: 14, weight: FontWeight.w700),
                        ),
                        Text(
                          '${alert.userName ?? 'Unknown user'} \u2022 ${formatAdminDateTime(alert.createdAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: orgText(p, size: 12, color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  switch (alert.severity) {
                    'high' => AdminBadge.danger(alert.severityLabel),
                    'low' => AdminBadge.neutral(alert.severityLabel),
                    _ => AdminBadge.warning(alert.severityLabel),
                  },
                ],
              ),
            ),
          if (open.length > 5) _moreLabel(open.length - 5),
        ],
      );
    }
    return _panel(
      title:
          'Recent Fraud Alerts${open.isEmpty ? '' : ' (${open.length} open)'}',
      action: 'View All',
      alertAction: true,
      onAction: () =>
          adminPushReplacement(context, const AdminFraudAlertsScreen()),
      child: body,
    );
  }

  Widget _buildActivityPanel() {
    final palette = FairTixPalette.of(context);
    final items = _activity;
    final failed = [
      _usersError,
      _alertsError,
      _refundsError,
    ].whereType<String>().isNotEmpty;
    final Widget body;
    if (_isLoading && items.isEmpty) {
      body = _spinner(leadingCircle: true, rows: 5);
    } else if (items.isEmpty) {
      body = _inlineMessage(
        failed
            ? 'Some activity could not be loaded. Use the refresh button to try again.'
            : 'No recent activity yet.',
      );
    } else {
      body = Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: palette.primary.withValues(
                      alpha: palette.isDark ? 0.22 : 0.10,
                    ),
                    child: Icon(
                      item.icon,
                      size: 17,
                      color: palette.accentLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.text,
                      style: orgText(palette, size: 13, height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatAdminDateTime(item.at),
                    style: orgText(
                      palette,
                      size: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              'Built from recent registrations, fraud alerts and refunds. Admin actions are not logged yet.',
              style: orgText(palette, size: 11, color: palette.textSecondary),
            ),
          ),
        ],
      );
    }

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Activity',
                  style: orgText(palette, size: 16, weight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _exportActivity,
                icon: Icon(
                  Icons.download_outlined,
                  size: 20,
                  color: palette.textSecondary,
                ),
                tooltip: 'Export activity',
              ),
            ],
          ),
          Divider(height: 16, color: palette.border),
          body,
        ],
      ),
    );
  }
}
