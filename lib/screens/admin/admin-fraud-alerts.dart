import 'package:flutter/material.dart';

import '../../services/admin_resale_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/csv_export.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';

/// The fraud / price-flag review queue.
///
/// Alerts are created by the database, not the app: the
/// `on_resale_listing_flag` trigger (supabase/fraud_alerts.sql) raises a
/// "near-floor price" or "rapid relisting" alert whenever a resale listing
/// is created. This screen lets an admin work through them: mark one as
/// being reviewed, resolve or dismiss it with a note, take the listing off
/// the market, or suspend the account involved.
class AdminFraudAlertsScreen extends StatefulWidget {
  const AdminFraudAlertsScreen({super.key});

  @override
  State<AdminFraudAlertsScreen> createState() => _AdminFraudAlertsScreenState();
}

class _AdminFraudAlertsScreenState extends State<AdminFraudAlertsScreen> {
  static const _filters = [
    'All',
    'System-Flagged',
    'Organizer-Flagged',
    'Resolved',
  ];

  /// Relative column widths (id, type, source, flagged user, timestamp,
  /// severity, status, action).
  static const _flex = [2, 3, 2, 4, 4, 2, 3, 2];

  List<FraudAlertEntry> _alerts = const [];
  bool _isLoading = true;
  String? _loadError;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final alerts = await AdminResaleService.instance.fetchAlerts();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _isLoading = false;
        _loadError = null;
      });
    } on AdminResaleException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  bool _matches(FraudAlertEntry a, String filter) => switch (filter) {
    'System-Flagged' => a.isSystem,
    'Organizer-Flagged' => !a.isSystem,
    'Resolved' => a.isClosed,
    _ => true,
  };

  List<FraudAlertEntry> get _filtered =>
      _alerts.where((a) => _matches(a, _filter)).toList();

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _review(FraudAlertEntry alert) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _AlertReviewDialog(alert: alert),
    );
    if (changed == true) {
      await _load(showSpinner: false);
      _toast('Alert updated.');
    }
  }

  Future<void> _exportCsv() async {
    final rows = _filtered;
    if (rows.isEmpty) {
      _toast('There are no fraud alerts to export.');
      return;
    }
    final csv = toCsv([
      [
        'Alert ID',
        'Type',
        'Source',
        'Flagged User',
        'Email',
        'Event',
        'Severity',
        'Status',
        'Created',
        'Reviewed',
        'Resolution Note',
        'Details',
      ],
      for (final a in rows)
        [
          a.id,
          a.typeLabel,
          a.sourceLabel,
          csvSafe(a.userName ?? ''),
          csvSafe(a.userEmail ?? ''),
          csvSafe(a.eventTitle ?? ''),
          a.severityLabel,
          a.statusLabel,
          a.createdAt.toIso8601String(),
          a.reviewedAt?.toIso8601String() ?? '',
          csvSafe(a.resolutionNote ?? ''),
          csvSafe(a.details),
        ],
    ]);
    final saved = await saveCsvFile(
      fileName: 'fairtix-fraud-alerts-${formatIsoDate(DateTime.now())}.csv',
      csv: csv,
    );
    _toast(saved ? 'Fraud alert log exported.' : 'Export canceled.');
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      active: AdminNavItem.fraudAlerts,
      title: 'Fraud Alerts',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final open = _alerts.where((a) => !a.isClosed).length;
    final ready = !_isLoading && _loadError == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Fraud Alerts',
          subtitle: '$open open alert${open == 1 ? '' : 's'}',
          actions: [
            AdminIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh data',
              loading: _isLoading,
              onPressed: _isLoading ? null : _load,
            ),
            AdminHeaderButton(
              icon: Icons.download_outlined,
              label: 'Export Log',
              onPressed: _isLoading ? null : _exportCsv,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminFilterChips(
          labels: _filters,
          selected: _filters.indexOf(_filter),
          counts: [
            for (final f in _filters)
              ready ? _alerts.where((a) => _matches(a, f)).length : null,
          ],
          onSelected: (i) => setState(() => _filter = _filters[i]),
        ),
        const SizedBox(height: 20),
        AdminCard(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: FairTixPalette.of(context).accentLabel,
                        ),
                      ),
                    )
                  : _loadError != null
                  ? AdminErrorBox(message: _loadError!, onRetry: _load)
                  : _buildTable(_filtered),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<FraudAlertEntry> filtered) {
    final p = FairTixPalette.of(context);
    if (filtered.isEmpty) {
      return AdminEmptyState(
        icon: Icons.shield_outlined,
        title: _alerts.isEmpty ? 'No fraud alerts yet' : 'No $_filter alerts',
        hint: _alerts.isEmpty
            ? 'Alerts appear here automatically when a resale listing is flagged.'
            : 'Try a different filter.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              const AdminTableHeader(
                labels: [
                  'Alert ID',
                  'Type',
                  'Source',
                  'Flagged user',
                  'Timestamp',
                  'Severity',
                  'Status',
                  '',
                ],
                flex: _flex,
              ),
            for (final alert in filtered)
              _AlertRow(
                alert: alert,
                wide: wide,
                flex: _flex,
                onReview: () => _review(alert),
              ),
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Showing ${filtered.length} of ${_alerts.length} alerts',
                style: orgText(p, size: 12, color: p.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }
}

AdminBadge _severityBadge(FraudAlertEntry a) => switch (a.severity) {
  'high' => AdminBadge.danger(a.severityLabel),
  'low' => AdminBadge.neutral(a.severityLabel),
  _ => AdminBadge.warning(a.severityLabel),
};

AdminBadge _alertStatusBadge(FraudAlertEntry a) => switch (a.status) {
  'reviewing' => AdminBadge.info(a.statusLabel),
  'resolved' => AdminBadge.success(a.statusLabel),
  'dismissed' => AdminBadge.neutral(a.statusLabel),
  _ => AdminBadge.warning(a.statusLabel),
};

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.alert,
    required this.wide,
    required this.flex,
    required this.onReview,
  });

  final FraudAlertEntry alert;
  final bool wide;
  final List<int> flex;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final reviewButton = AdminRowAction(
      label: alert.isClosed ? 'View' : 'Review',
      filled: !alert.isClosed,
      onPressed: onReview,
    );
    final user = alert.userName ?? 'Unknown user';

    if (wide) {
      return AdminTableRow(
        children: [
          adminCell(context, flex[0], alert.shortId, bold: true),
          adminCell(context, flex[1], alert.typeLabel),
          adminCell(context, flex[2], alert.sourceLabel),
          Expanded(
            flex: flex[3],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(
                      p,
                      size: 13,
                      weight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (alert.eventTitle != null)
                    Text(
                      alert.eventTitle!,
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
          adminCell(
            context,
            flex[4],
            formatAdminDateTime(alert.createdAt),
            muted: true,
          ),
          Expanded(
            flex: flex[5],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _severityBadge(alert),
            ),
          ),
          Expanded(
            flex: flex[6],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _alertStatusBadge(alert),
            ),
          ),
          Expanded(
            flex: flex[7],
            child: Align(alignment: Alignment.centerLeft, child: reviewButton),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${alert.typeLabel}  \u2022  ${alert.shortId}',
                  style: orgText(p, size: 14, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              _severityBadge(alert),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$user${alert.eventTitle != null ? ' \u2022 ${alert.eventTitle}' : ''}',
            style: orgText(p, size: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _alertStatusBadge(alert),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  formatAdminDateTime(alert.createdAt),
                  style: orgText(p, size: 12, color: p.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: reviewButton),
        ],
      ),
    );
  }
}

/// Review dialog for one alert. Pops `true` when anything changed, so the
/// screen knows to reload the list.
class _AlertReviewDialog extends StatefulWidget {
  const _AlertReviewDialog({required this.alert});

  final FraudAlertEntry alert;

  @override
  State<_AlertReviewDialog> createState() => _AlertReviewDialogState();
}

class _AlertReviewDialogState extends State<_AlertReviewDialog> {
  late final TextEditingController _note;
  bool _busy = false;
  bool _changed = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.alert.resolutionNote ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Runs [action]. With [closeAfter] the dialog closes on success (used for
  /// status changes); otherwise it stays open and shows [success] (used for
  /// the side actions, so the admin can still resolve the alert afterwards).
  Future<void> _run(
    Future<void> Function() action, {
    String? success,
    bool closeAfter = false,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
      _changed = true;
      if (!mounted) return;
      if (closeAfter) {
        Navigator.pop(context, true);
        return;
      }
      setState(() => _info = success);
    } on AdminResaleException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AdminUserServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _fact(FairTixPalette p, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: orgText(p, size: 12, color: p.textSecondary, height: 1.4),
          ),
        ),
        Expanded(child: Text(value, style: orgText(p, size: 13, height: 1.4))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final a = widget.alert;
    final svc = AdminResaleService.instance;
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      a.typeLabel,
                      style: orgText(p, size: 18, weight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _severityBadge(a),
                  const SizedBox(width: 6),
                  _alertStatusBadge(a),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Alert ${a.shortId} \u2022 ${a.sourceLabel}-flagged',
                style: orgText(p, size: 13, color: p.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.progressTrack,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Text(
                  a.details,
                  style: orgText(p, size: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 16),
              _fact(
                p,
                'Flagged user',
                a.userName == null
                    ? 'Unknown'
                    : '${a.userName}${a.userEmail == null ? '' : ' (${a.userEmail})'}',
              ),
              if (a.eventTitle != null) _fact(p, 'Event', a.eventTitle!),
              _fact(p, 'Flagged', formatAdminDateTime(a.createdAt)),
              if (a.reviewedAt != null)
                _fact(p, 'Last reviewed', formatAdminDateTime(a.reviewedAt!)),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                enabled: !_busy,
                maxLines: 3,
                maxLength: 500,
                style: orgText(p, size: 14, height: 1.4),
                cursorColor: p.accentLabel,
                decoration: adminInputDecoration(
                  context,
                  label: 'Review note (optional)',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: Text(
                    _error!,
                    style: orgText(p, size: 13, color: p.danger),
                  ),
                ),
              if (_info != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: Text(
                    _info!,
                    style: orgText(
                      p,
                      size: 13,
                      weight: FontWeight.w600,
                      color: p.success,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (a.status == 'open')
                    AdminHeaderButton(
                      label: 'Mark Reviewing',
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => svc.updateAlert(
                                a.id,
                                'reviewing',
                                note: _note.text,
                              ),
                              closeAfter: true,
                            ),
                    ),
                  AdminHeaderButton(
                    label: 'Resolve',
                    filled: true,
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => svc.updateAlert(
                              a.id,
                              'resolved',
                              note: _note.text,
                            ),
                            closeAfter: true,
                          ),
                  ),
                  AdminHeaderButton(
                    label: 'Dismiss',
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => svc.updateAlert(
                              a.id,
                              'dismissed',
                              note: _note.text,
                            ),
                            closeAfter: true,
                          ),
                  ),
                ],
              ),
              if (a.listingId != null || a.userId != null) ...[
                Divider(height: 32, color: p.border),
                Text(
                  'Take action',
                  style: orgText(p, size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (a.listingId != null)
                      AdminRowAction(
                        label: 'Remove Listing',
                        color: p.danger,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => svc.removeListing(
                                  a.listingId!,
                                  reason: _note.text.trim(),
                                ),
                                success:
                                    'Listing removed and the seller was notified.',
                              ),
                      ),
                    if (a.userId != null)
                      AdminRowAction(
                        label: 'Suspend User',
                        color: p.danger,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () =>
                                    AdminUserService.instance.setAccountStatus(
                                      userId: a.userId!,
                                      status: 'suspended',
                                    ),
                                success:
                                    'Account suspended. It can be reactivated from Accounts.',
                              ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: AdminDialogButton(
                  label: 'Close',
                  onPressed: _busy
                      ? null
                      : () => Navigator.pop(context, _changed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
