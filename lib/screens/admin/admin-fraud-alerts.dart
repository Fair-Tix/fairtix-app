import 'package:flutter/material.dart';

import '../../services/admin_resale_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/csv_export.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../organizer/app_colors.dart';

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
  static const _filters = ['All', 'System-Flagged', 'Organizer-Flagged', 'Resolved'];

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

  List<FraudAlertEntry> get _filtered => _alerts.where((a) => _matches(a, _filter)).toList();

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        'Alert ID', 'Type', 'Source', 'Flagged User', 'Email', 'Event', 'Severity',
        'Status', 'Created', 'Reviewed', 'Resolution Note', 'Details',
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
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Fraud Alerts', style: AppTextStyles.h2)),
            Text(
              '$open open alert${open == 1 ? '' : 's'}',
              style: TextStyle(
                color: open > 0 ? AppColors.dangerRed : AppColors.textGray,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh',
            ),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _exportCsv,
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export Log', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _filters) ...[
                ChoiceChip(
                  label: Text(
                    '$filter  ${_alerts.where((a) => _matches(a, filter)).length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                  selectedColor: AppColors.primaryPurple,
                  labelStyle: TextStyle(
                    color: _filter == filter ? Colors.white : AppColors.textDark,
                  ),
                  side: BorderSide(
                    color: _filter == filter ? AppColors.primaryPurple : AppColors.borderLight,
                  ),
                  showCheckmark: false,
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdminCard(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              : _loadError != null
              ? AdminErrorBox(message: _loadError!, onRetry: _load)
              : _buildTable(filtered),
        ),
      ],
    );
  }

  Widget _buildTable(List<FraudAlertEntry> filtered) {
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
        final wide = constraints.maxWidth >= 820;
        return Column(
          children: [
            if (wide)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 12, 14, 10),
                child: Row(
                  children: [
                    Expanded(child: Text('ALERT ID', style: adminHeaderStyle)),
                    Expanded(flex: 2, child: Text('TYPE', style: adminHeaderStyle)),
                    Expanded(child: Text('SOURCE', style: adminHeaderStyle)),
                    Expanded(flex: 2, child: Text('FLAGGED USER', style: adminHeaderStyle)),
                    Expanded(flex: 2, child: Text('TIMESTAMP', style: adminHeaderStyle)),
                    Expanded(child: Text('SEVERITY', style: adminHeaderStyle)),
                    Expanded(child: Text('STATUS', style: adminHeaderStyle)),
                    SizedBox(width: 70, child: Text('ACTION', style: adminHeaderStyle)),
                  ],
                ),
              ),
            const Divider(height: 1),
            for (final alert in filtered) _AlertRow(alert: alert, wide: wide, onReview: () => _review(alert)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${filtered.length} of ${_alerts.length} alerts',
                  style: const TextStyle(color: AppColors.textGray, fontSize: 10),
                ),
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
  const _AlertRow({required this.alert, required this.wide, required this.onReview});

  final FraudAlertEntry alert;
  final bool wide;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final reviewButton = TextButton(
      onPressed: onReview,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
      child: Text(
        alert.isClosed ? 'View' : 'Review',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
    final user = alert.userName ?? 'Unknown user';

    final content = wide
        ? Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
            child: Row(
              children: [
                Expanded(child: Text(alert.shortId, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Text(alert.typeLabel, style: const TextStyle(fontSize: 11))),
                Expanded(child: Text(alert.sourceLabel, style: const TextStyle(fontSize: 11))),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      if (alert.eventTitle != null)
                        Text(alert.eventTitle!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text(formatAdminDateTime(alert.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.textGray))),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: _severityBadge(alert))),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: _alertStatusBadge(alert))),
                SizedBox(width: 70, child: reviewButton),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${alert.typeLabel}  \u2022  ${alert.shortId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    _severityBadge(alert),
                  ],
                ),
                const SizedBox(height: 3),
                Text('$user${alert.eventTitle != null ? ' \u2022 ${alert.eventTitle}' : ''}', style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _alertStatusBadge(alert),
                    const SizedBox(width: 8),
                    Text(formatAdminDateTime(alert.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
                  ],
                ),
                reviewButton,
              ],
            ),
          );
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
      child: content,
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

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGray))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11.5))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final svc = AdminResaleService.instance;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(a.typeLabel, style: AppTextStyles.h3)),
                  _severityBadge(a),
                  const SizedBox(width: 6),
                  _alertStatusBadge(a),
                ],
              ),
              const SizedBox(height: 4),
              Text('Alert ${a.shortId} \u2022 ${a.sourceLabel}-flagged', style: AppTextStyles.bodyGray.copyWith(fontSize: 12)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(a.details, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 14),
              _fact('Flagged user', a.userName == null ? 'Unknown' : '${a.userName}${a.userEmail == null ? '' : ' (${a.userEmail})'}'),
              if (a.eventTitle != null) _fact('Event', a.eventTitle!),
              _fact('Flagged', formatAdminDateTime(a.createdAt)),
              if (a.reviewedAt != null) _fact('Last reviewed', formatAdminDateTime(a.reviewedAt!)),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                enabled: !_busy,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Review note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 12)),
                ),
              if (_info != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_info!, style: const TextStyle(color: AppColors.successGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (a.status == 'open')
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => svc.updateAlert(a.id, 'reviewing', note: _note.text), closeAfter: true),
                      child: const Text('Mark Reviewing'),
                    ),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => svc.updateAlert(a.id, 'resolved', note: _note.text), closeAfter: true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.successGreen),
                    child: const Text('Resolve'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => svc.updateAlert(a.id, 'dismissed', note: _note.text), closeAfter: true),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
              if (a.listingId != null || a.userId != null) ...[
                const Divider(height: 28),
                const Text('Take action', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (a.listingId != null)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => svc.removeListing(a.listingId!, reason: _note.text.trim()),
                                success: 'Listing removed and the seller was notified.',
                              ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerRed,
                          side: const BorderSide(color: AppColors.dangerRed),
                        ),
                        child: const Text('Remove Listing'),
                      ),
                    if (a.userId != null)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => AdminUserService.instance.setAccountStatus(
                                  userId: a.userId!,
                                  status: 'suspended',
                                ),
                                success: 'Account suspended. It can be reactivated from Accounts.',
                              ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerRed,
                          side: const BorderSide(color: AppColors.dangerRed),
                        ),
                        child: const Text('Suspend User'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, _changed),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
