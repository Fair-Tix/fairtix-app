import 'package:flutter/material.dart';

import '../../services/admin_overview_service.dart';
import '../../services/admin_refund_service.dart';
import '../../services/admin_report_service.dart';
import '../../services/admin_resale_service.dart';
import '../../services/admin_revenue_service.dart';
import '../../services/csv_export.dart';
import '../../theme/fairtix_palette.dart';
import '../../services/pdf_export.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/ft_skeleton.dart';
import '../../widgets/organizer_ui.dart';

/// Placeholder bars for a chart panel while its data loads.
class _SkeletonBars extends StatelessWidget {
  const _SkeletonBars();

  static const _heights = [
    0.35, 0.5, 0.3, 0.65, 0.45, 0.8, 0.55, 0.4,
    0.7, 0.5, 0.9, 0.6, 0.35, 0.75, 0.5, 0.65,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final h in _heights)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: h,
                  widthFactor: 1,
                  child: const FtSkeletonBox(radius: 3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Placeholder for the "Revenue Breakdown by Plan" rows (label + percent, bar,
/// caption), three of them.
class _SkeletonBreakdown extends StatelessWidget {
  const _SkeletonBreakdown();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        children: [
          _SkeletonBreakdownRow(),
          _SkeletonBreakdownRow(),
          _SkeletonBreakdownRow(),
        ],
      ),
    );
  }
}

class _SkeletonBreakdownRow extends StatelessWidget {
  const _SkeletonBreakdownRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FtSkeletonBox(width: 150, height: 13),
              Spacer(),
              FtSkeletonBox(width: 30, height: 13),
            ],
          ),
          SizedBox(height: 6),
          FtSkeletonBox(height: 8, radius: 4),
          SizedBox(height: 5),
          FtSkeletonBox(width: 130, height: 12),
        ],
      ),
    );
  }
}

/// Platform earnings, the refund log and CSV report exports.
///
/// Every number comes from Supabase:
///  - summary cards + "Platform Fees by Plan": `admin_revenue_by_plan`
///    (the range chips at the top change this and the exports)
///  - daily chart + monthly table: `admin_revenue_daily` /
///    `admin_revenue_monthly` (always the last 30 days / this year,
///    independent of the range chips, as their titles say)
///  - refund log: `public.refunds`
class AdminRevenueReportsScreen extends StatefulWidget {
  const AdminRevenueReportsScreen({super.key});

  @override
  State<AdminRevenueReportsScreen> createState() =>
      _AdminRevenueReportsScreenState();
}

class _AdminRevenueReportsScreenState extends State<AdminRevenueReportsScreen> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _ranges = ['This Week', 'This Month', 'Custom Range'];

  String _range = 'This Month';
  DateTimeRange? _customRange;

  List<PlanRevenue> _plans = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<RefundEntry> _refunds = [];
  bool _isLoadingRefunds = true;
  String? _refundError;

  List<DailyRevenue> _daily = [];
  List<MonthlyRevenue> _monthly = [];
  bool _isLoadingCharts = true;
  String? _chartsError;

  bool _isExporting = false;

  /// 'Approved only' option of the User Accounts export (off = all accounts).
  bool _approvedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadRevenue();
    _loadRefunds();
    _loadCharts();
  }

  /// Inclusive start / exclusive end of the selected range, or (null, null)
  /// for a Custom Range that hasn't been picked yet (= all time).
  (DateTime?, DateTime?) _rangeBounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case 'This Week':
        final monday = today.subtract(Duration(days: now.weekday - 1));
        return (monday, monday.add(const Duration(days: 7)));
      case 'This Month':
        return (
          DateTime(now.year, now.month),
          DateTime(now.year, now.month + 1),
        );
      default:
        final custom = _customRange;
        if (custom == null) return (null, null);
        return (
          DateTime(custom.start.year, custom.start.month, custom.start.day),
          DateTime(custom.end.year, custom.end.month, custom.end.day + 1),
        );
    }
  }

  String _rangeLabel() {
    final (from, to) = _rangeBounds();
    if (from == null || to == null) return 'all time';
    String d(DateTime x) => '${x.month}/${x.day}/${x.year}';
    return '${d(from)} \u2013 ${d(to.subtract(const Duration(days: 1)))}';
  }

  Future<void> _selectRange(String range) async {
    if (range != 'Custom Range') {
      setState(() => _range = range);
      await _loadRevenue();
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customRange,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _customRange = picked;
      _range = range;
    });
    await _loadRevenue();
  }

  // ── loading ──────────────────────────────────────────────────────────

  Future<void> _loadRevenue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final (from, to) = _rangeBounds();
      final plans = await AdminRevenueService.instance.fetchByPlan(
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() => _plans = plans);
    } on AdminRevenueException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRefunds() async {
    setState(() {
      _isLoadingRefunds = true;
      _refundError = null;
    });
    try {
      final refunds = await AdminRefundService.instance.fetchRefunds();
      if (!mounted) return;
      setState(() => _refunds = refunds);
    } on AdminRefundException catch (e) {
      if (!mounted) return;
      setState(() => _refundError = e.message);
    } finally {
      if (mounted) setState(() => _isLoadingRefunds = false);
    }
  }

  Future<void> _loadCharts() async {
    setState(() {
      _isLoadingCharts = true;
      _chartsError = null;
    });
    try {
      final daily = await AdminOverviewService.instance.fetchDaily(days: 30);
      final monthly = await AdminOverviewService.instance.fetchMonthly(
        DateTime.now().year,
      );
      if (!mounted) return;
      setState(() {
        _daily = daily;
        _monthly = monthly;
      });
    } on AdminOverviewException catch (e) {
      if (!mounted) return;
      setState(() => _chartsError = e.message);
    } finally {
      if (mounted) setState(() => _isLoadingCharts = false);
    }
  }

  Future<void> _refreshAll() =>
      Future.wait([_loadRevenue(), _loadRefunds(), _loadCharts()]);

  // ── refunds ──────────────────────────────────────────────────────────

  Future<void> _processRefund(RefundEntry refund) async {
    final referenceController = TextEditingController();
    final providerRefundId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record confirmed PayMongo refund'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Issue ${formatPeso(refund.amount)} to ${refund.buyerName} in PayMongo first, then enter its refund ID.'),
          const SizedBox(height: 16),
          TextField(
            controller: referenceController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'PayMongo refund ID', hintText: 're_…'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = referenceController.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Record confirmation'),
          ),
        ],
      ),
    );
    referenceController.dispose();
    if (!mounted || providerRefundId == null) return;
    try {
      await AdminRefundService.instance.markProcessed(refund.id, providerRefundId);
      if (!mounted) return;
      _showMessage('PayMongo refund confirmation recorded.');
      await _refreshAll();
    } on AdminRefundException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    }
  }

  // ── exports ──────────────────────────────────────────────────────────

  /// Builds the report rows (first row = header) for the selected range and
  /// saves them as CSV or PDF.
  Future<void> _exportReport(
    String slug,
    String title,
    Future<List<List<Object?>>> Function(DateTime? from, DateTime? to) build, {
    required bool pdf,
    bool showTotals = false,
  }) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final (from, to) = _rangeBounds();
      final rows = await build(from, to);
      final ext = pdf ? 'pdf' : 'csv';
      final fileName = 'fairtix_${slug}_${formatIsoDate(DateTime.now())}.$ext';
      final saved = pdf
          ? await savePdfReport(
              fileName: fileName,
              title: title,
              subtitle: 'Range: ${_rangeLabel()}',
              rows: rows,
              showTotals: showTotals,
            )
          : await saveCsvReport(
              fileName: fileName,
              title: title,
              subtitle: 'Range: ${_rangeLabel()}',
              rows: rows,
              showTotals: showTotals,
            );
      if (!mounted) return;
      if (saved) _showMessage('Report exported ($fileName).');
    } on AdminReportException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } on AdminResaleException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not save the report: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportTransactions({required bool pdf}) => _exportReport(
    'transactions',
    'Transaction Report',
    (from, to) =>
        AdminReportService.instance.transactionReportRows(from: from, to: to),
    pdf: pdf,
  );

  Future<void> _exportRevenue({required bool pdf}) => _exportReport(
    'revenue',
    'Revenue Report',
    (from, to) =>
        AdminReportService.instance.revenueReportRows(from: from, to: to),
    pdf: pdf,
    showTotals: true,
  );

  Future<void> _exportRefunds({required bool pdf}) => _exportReport(
    'refunds',
    'Refund Report',
    (from, to) =>
        AdminReportService.instance.refundReportRows(from: from, to: to),
    pdf: pdf,
    showTotals: true,
  );

  Future<void> _exportResale({required bool pdf}) => _exportReport(
    'resale_activity',
    'Resale Activity Report',
    (from, to) =>
        AdminReportService.instance.resaleActivityReportRows(from: from, to: to),
    pdf: pdf,
  );

  Future<void> _exportOrganizerSubscriptions({required bool pdf}) =>
      _exportReport(
        'organizer_subscriptions',
        'Organizer Subscription Report',
        (from, to) => AdminReportService.instance
            .organizerSubscriptionReportRows(from: from, to: to),
        pdf: pdf,
      );

  Future<void> _exportEventsTickets({required bool pdf}) => _exportReport(
    'events_tickets',
    'Events and Tickets Report',
    (from, to) => AdminReportService.instance.eventsAndTicketsReportRows(
      from: from,
      to: to,
    ),
    pdf: pdf,
  );

  Future<void> _exportScannerActivity({required bool pdf}) => _exportReport(
    'scanner_checkin',
    'Scanner and Check-in Report',
    (from, to) => AdminReportService.instance.scannerActivityReportRows(
      from: from,
      to: to,
    ),
    pdf: pdf,
  );

  Future<void> _exportUserAccounts({required bool pdf}) => _exportReport(
    _approvedOnly ? 'user_accounts_approved' : 'user_accounts',
    _approvedOnly
        ? 'User Accounts Report (approved only)'
        : 'User Accounts Report',
    (from, to) => AdminReportService.instance.userAccountsReportRows(
      from: from,
      to: to,
      approvedOnly: _approvedOnly,
    ),
    pdf: pdf,
  );

  Future<void> _exportFraudAlerts({required bool pdf}) => _exportReport(
    'fraud_alerts',
    'Fraud Alerts Report',
    (from, to) =>
        AdminReportService.instance.fraudAlertsReportRows(from: from, to: to),
    pdf: pdf,
  );

  Future<void> _exportApplicationReviews({required bool pdf}) => _exportReport(
    'application_reviews',
    'Application Reviews Report',
    (from, to) => AdminReportService.instance.applicationReviewsReportRows(
      from: from,
      to: to,
    ),
    pdf: pdf,
  );

  Future<void> _exportAdminAuditLog({required bool pdf}) => _exportReport(
    'admin_audit_log',
    'Admin Audit Log Report',
    (from, to) =>
        AdminReportService.instance.adminAuditLogReportRows(from: from, to: to),
    pdf: pdf,
  );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      active: AdminNavItem.revenueReports,
      title: 'Revenue & Reports',
      body: _buildContent(MediaQuery.of(context).size.width >= 1100),
    );
  }

  Widget _buildContent(bool isWide) {
    final p = FairTixPalette.of(context);
    final revenue = _plans.fold<double>(0, (sum, e) => sum + e.gross);
    final fees = _plans.fold<double>(0, (sum, e) => sum + e.fees);
    final payouts = _plans.fold<double>(0, (sum, e) => sum + e.net);
    final hasData = _plans.any((e) => e.tickets > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Revenue & Reports',
          subtitle: 'Track platform earnings and export financial data',
          actions: [
            AdminIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh data',
              loading: _isLoading || _isLoadingRefunds || _isLoadingCharts,
              onPressed: _isLoading || _isLoadingRefunds || _isLoadingCharts
                  ? null
                  : _refreshAll,
            ),
            _buildExportMenu(),
          ],
        ),
        const SizedBox(height: 20),
        AdminFilterChips(
          labels: _ranges,
          selected: _ranges.indexOf(_range),
          onSelected: (i) => _selectRange(_ranges[i]),
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null) ...[
          _buildErrorBanner(),
          const SizedBox(height: 16),
        ],
        if (_isLoading)
          const FtShimmer(child: AdminSkeletonSummaryRow(count: 3))
        else
        AdminSummaryRow(
          cards: [
            AdminSummaryCard(
              icon: Icons.payments_outlined,
              color: p.accentLabel,
              label: 'Total Revenue',
              value: formatPeso(revenue),
              caption: hasData
                  ? 'From recorded ticket sales'
                  : 'No sales data yet',
            ),
            AdminSummaryCard(
              icon: Icons.percent_outlined,
              color: p.accentLabel,
              label: 'Platform Fees',
              value: formatPeso(fees),
              caption: hasData
                  ? 'Per plan: ${_feeRatesCaption()}'
                  : 'No fee data yet',
            ),
            AdminSummaryCard(
              icon: Icons.sell_outlined,
              color: p.success,
              label: 'Net Payouts',
              value: formatPeso(payouts),
              caption: hasData ? 'After platform fees' : 'No payout data yet',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildFeesByPlan(),
        const SizedBox(height: 20),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDailyRevenue()),
              const SizedBox(width: 20),
              Expanded(child: _buildBreakdown(revenue)),
            ],
          )
        else ...[
          _buildDailyRevenue(),
          const SizedBox(height: 20),
          _buildBreakdown(revenue),
        ],
        const SizedBox(height: 20),
        _buildMonthlyBreakdown(),
        const SizedBox(height: 20),
        _buildRefundLog(),
        const SizedBox(height: 28),
        _buildExportReports(),
      ],
    );
  }

  /// "Export" dropdown in the page header (revenue report as CSV or PDF).
  Widget _buildExportMenu() {
    final p = FairTixPalette.of(context);
    final fg = _isExporting ? p.textSecondary : p.accentLabel;
    return PopupMenuButton<bool>(
      enabled: !_isExporting,
      tooltip: 'Export the revenue report',
      color: p.surface,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.border),
      ),
      onSelected: (pdf) => _exportRevenue(pdf: pdf),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: false,
          child: Text(
            'Export as CSV',
            style: orgText(p, size: 14, weight: FontWeight.w600),
          ),
        ),
        PopupMenuItem(
          value: true,
          child: Text(
            'Export as PDF',
            style: orgText(p, size: 14, weight: FontWeight.w600),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined, size: 16, color: fg),
            const SizedBox(width: 7),
            Text(
              _isExporting ? 'Exporting...' : 'Export',
              style: orgText(
                p,
                size: 13,
                weight: FontWeight.w700,
                color: fg,
                height: 1.2,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: fg),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.dangerSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.danger),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _errorMessage!,
              style: orgText(p, size: 13, color: p.danger),
            ),
          ),
          const SizedBox(width: 12),
          AdminRowAction(
            label: 'Retry',
            color: p.danger,
            onPressed: _loadRevenue,
          ),
        ],
      ),
    );
  }

  /// The distinct fee rates in use, e.g. 8% / 9% / 10%, from the live plans.
  String _feeRatesCaption() {
    final labels = <String>[];
    for (final plan in _plans) {
      if (!labels.contains(plan.rateLabel)) labels.add(plan.rateLabel);
    }
    return labels.join(' / ');
  }

  /// Lets a wide table keep its [minWidth] on a phone by scrolling sideways
  /// instead of squeezing its columns.
  Widget _scrollable(double minWidth, Widget child) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= minWidth) return child;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: minWidth, child: child),
      );
    },
  );

  Widget _buildFeesByPlan() {
    const flex = [2, 1, 1, 2, 2];
    final p = FairTixPalette.of(context);
    return _panel(
      title: 'Platform Fees by Plan',
      trailing: _isLoading ? 'Loading...' : _rangeLabel(),
      child: _scrollable(
        560,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminTableHeader(
              labels: [
                'Plan',
                'Fee rate',
                'Tickets',
                'Ticket revenue',
                'Platform fees',
              ],
              flex: flex,
            ),
            if (_isLoading)
              FtShimmer(
                child: AdminSkeletonTableBody(
                  flex: flex,
                  rows: 3,
                  showHeader: false,
                ),
              )
            else
            for (final plan in _plans)
              AdminTableRow(
                children: [
                  adminCell(context, flex[0], plan.plan, bold: true),
                  Expanded(
                    flex: flex[1],
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        plan.rateLabel,
                        style: orgText(
                          p,
                          size: 13,
                          weight: FontWeight.w700,
                          color: p.accentLabel,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  adminCell(context, flex[2], '${plan.tickets}'),
                  adminCell(context, flex[3], formatPeso(plan.gross)),
                  adminCell(context, flex[4], formatPeso(plan.fees)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chartSpinner() => const FtShimmer(
    child: SizedBox(
      height: 220,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: _SkeletonBars(),
      ),
    ),
  );

  Widget _buildDailyRevenue() {
    final p = FairTixPalette.of(context);
    final total = _daily.fold<double>(0, (sum, d) => sum + d.gross);
    final maxGross = _daily.fold<double>(
      0,
      (m, d) => d.gross > m ? d.gross : m,
    );

    final Widget body;
    if (_isLoadingCharts) {
      body = _chartSpinner();
    } else if (_chartsError != null) {
      body = AdminErrorBox(message: _chartsError!, onRetry: _loadCharts);
    } else if (total <= 0) {
      body = const SizedBox(
        height: 220,
        child: AdminEmptyState(
          icon: Icons.show_chart,
          title: 'No sales in the last 30 days',
          hint: 'Daily ticket revenue will appear here as tickets are sold.',
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SizedBox(
          height: 190,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in _daily)
                      Expanded(
                        child: Tooltip(
                          message:
                              '${formatAdminDate(d.day)}\n${formatPeso(d.gross)} \u2022 ${d.tickets} ticket${d.tickets == 1 ? '' : 's'}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: d.gross <= 0
                                    ? 0.012
                                    : (d.gross / maxGross)
                                          .clamp(0.03, 1.0)
                                          .toDouble(),
                                widthFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: d.gross > 0 ? p.primary : p.border,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    formatAdminDate(_daily.first.day),
                    style: orgText(p, size: 11, color: p.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    formatAdminDate(_daily.last.day),
                    style: orgText(p, size: 11, color: p.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return _panel(
      title: 'Daily Revenue \u2013 Last 30 Days',
      trailing: (_isLoadingCharts || _chartsError != null)
          ? null
          : '${formatPeso(total)} total',
      child: body,
    );
  }

  Widget _buildBreakdown(double revenue) {
    final p = FairTixPalette.of(context);
    return _panel(
      title: 'Revenue Breakdown by Plan',
      trailing: _isLoading ? null : formatPeso(revenue),
      child: _isLoading
          ? const FtShimmer(child: _SkeletonBreakdown())
          : revenue <= 0
          ? const SizedBox(
              height: 220,
              child: AdminEmptyState(
                icon: Icons.donut_large_outlined,
                title: 'No revenue in this range',
                hint: 'Ticket revenue by organizer plan will show here.',
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                children: [
                  for (final plan in _plans)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${plan.plan} (${plan.rateLabel} fee)',
                                  style: orgText(
                                    p,
                                    size: 13,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${(plan.gross / revenue * 100).round()}%',
                                style: orgText(
                                  p,
                                  size: 13,
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: plan.gross / revenue,
                              minHeight: 8,
                              backgroundColor: p.progressTrack,
                              color: p.primary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${formatPeso(plan.gross)} \u2022 ${plan.tickets} ticket${plan.tickets == 1 ? '' : 's'}',
                            style: orgText(
                              p,
                              size: 12,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthlyBreakdown() {
    const flex = [2, 2, 2, 2, 1];
    final p = FairTixPalette.of(context);
    final year = DateTime.now().year;
    // Only months up to the current one; future months are always empty.
    final months = _monthly.take(DateTime.now().month).toList();
    final hasSales = months.any((m) => m.hasSales);

    String growth(int i) {
      if (i == 0) return '\u2014';
      final prev = months[i - 1].gross;
      if (prev <= 0) return '\u2014';
      final pct = ((months[i].gross - prev) / prev * 100).round();
      return '${pct > 0 ? '+' : ''}$pct%';
    }

    Color growthColor(String text) {
      if (text.startsWith('+')) return p.success;
      if (text.startsWith('-')) return p.danger;
      return p.textSecondary;
    }

    final Widget body;
    if (_isLoadingCharts) {
      body = FtShimmer(child: AdminSkeletonTableBody(flex: flex, rows: 4));
    } else if (_chartsError != null) {
      body = AdminErrorBox(message: _chartsError!, onRetry: _loadCharts);
    } else if (!hasSales) {
      body = AdminEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No sales recorded in $year yet',
        hint: 'Monthly figures will appear here once tickets are sold.',
      );
    } else {
      body = _scrollable(
        620,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminTableHeader(
              labels: [
                'Month',
                'Ticket revenue',
                'Platform fees',
                'Net payouts',
                'Growth',
              ],
              flex: flex,
            ),
            for (var i = 0; i < months.length; i++)
              AdminTableRow(
                children: [
                  adminCell(
                    context,
                    flex[0],
                    _monthNames[months[i].month - 1],
                    bold: true,
                  ),
                  adminCell(context, flex[1], formatPeso(months[i].gross)),
                  adminCell(context, flex[2], formatPeso(months[i].fees)),
                  adminCell(context, flex[3], formatPeso(months[i].net)),
                  Expanded(
                    flex: flex[4],
                    child: Text(
                      growth(i),
                      style: orgText(
                        p,
                        size: 13,
                        weight: FontWeight.w700,
                        color: growthColor(growth(i)),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return _panel(title: 'Monthly Breakdown', trailing: '$year', child: body);
  }

  Widget _buildRefundLog() {
    const flex = [3, 3, 3, 2, 2, 3];
    final pending = _refunds.where((r) => !r.isProcessed).length;
    final Widget body;
    if (_refundError != null) {
      body = AdminErrorBox(message: _refundError!, onRetry: _loadRefunds);
    } else if (_isLoadingRefunds) {
      body = FtShimmer(child: AdminSkeletonTableBody(flex: flex, rows: 3));
    } else if (_refunds.isEmpty) {
      body = const AdminEmptyState(
        icon: Icons.assignment_return_outlined,
        title: 'No refunds yet',
        hint: 'Refunds appear here when an event is canceled.',
      );
    } else {
      body = _scrollable(
        820,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminTableHeader(
              labels: ['Date', 'Event', 'Buyer', 'Amount', 'Status', ''],
              flex: flex,
            ),
            for (final refund in _refunds)
              AdminTableRow(
                children: [
                  adminCell(
                    context,
                    flex[0],
                    formatAdminDateTime(refund.createdAt),
                    muted: true,
                  ),
                  adminCell(context, flex[1], refund.eventTitle),
                  adminCell(context, flex[2], refund.buyerName),
                  adminCell(context, flex[3], formatPeso(refund.amount)),
                  Expanded(
                    flex: flex[4],
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: refund.isProcessed
                          ? AdminBadge.success(refund.statusLabel)
                          : AdminBadge.warning(refund.statusLabel),
                    ),
                  ),
                  Expanded(
                    flex: flex[5],
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: refund.isProcessed
                          ? const SizedBox.shrink()
                          : AdminRowAction(
                              label: 'Record Provider Refund',
                              onPressed: () => _processRefund(refund),
                            ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return _panel(
      title: 'Refund Log',
      trailing: _isLoadingRefunds
          ? 'Loading...'
          : '${_refunds.length} total \u2022 $pending pending',
      child: body,
    );
  }

  Widget _buildExportReports() {
    final p = FairTixPalette.of(context);
    // The last field is the export action (pdf: true/false), or null when
    // the report isn't available yet.
    final reports =
        <
          (
            IconData,
            String,
            String,
            Future<void> Function({required bool pdf})?,
          )
        >[
          (
            Icons.receipt_long_outlined,
            'Transaction Report',
            'Every purchase and resale with buyer, event, tier, amount, fee, and status.',
            _exportTransactions,
          ),
          (
            Icons.payments_outlined,
            'Revenue Report',
            'Platform fees per organizer plan with gross, fee, and net totals.',
            _exportRevenue,
          ),
          (
            Icons.assignment_return_outlined,
            'Refund Report',
            'Every refund with its event, buyer, amount, and processed status.',
            _exportRefunds,
          ),
          (
            Icons.sync_outlined,
            'Resale Activity Report',
            'Every resale listing with seller, buyer, event, price versus original, and status.',
            _exportResale,
          ),
          (
            Icons.workspace_premium_outlined,
            'Organizer Subscription Report',
            'Each organizer with their plan, platform fee rate, status and dates.',
            _exportOrganizerSubscriptions,
          ),
          (
            Icons.manage_accounts_outlined,
            'User Accounts Report',
            'Every account with email, registration and approval date, status, plus summary counts.',
            _exportUserAccounts,
          ),
          (
            Icons.event_note_outlined,
            'Events and Tickets Report',
            'Each event and ticket tier: organizer, status, capacity, sold, canceled, used.',
            _exportEventsTickets,
          ),
          (
            Icons.qr_code_scanner_outlined,
            'Scanner and Check-in Report',
            'Every QR scan: event, session, time, accepted or rejected, ticket tier.',
            _exportScannerActivity,
          ),
          (
            Icons.report_problem_outlined,
            'Fraud Alerts Report',
            'Every price flag and alert: severity, status, flagged user, reviewer and resolution note.',
            _exportFraudAlerts,
          ),
          (
            Icons.fact_check_outlined,
            'Application Reviews Report',
            'Each application step: submitted, approved, rejected, resubmitted, with reason and admin.',
            _exportApplicationReviews,
          ),
          (
            Icons.history_outlined,
            'Admin Audit Log Report',
            'What admins did: approvals, suspensions, alert reviews, removals, cancellations.',
            _exportAdminAuditLog,
          ),
        ];
    // Cards are grouped under small headings by title. A card that is not
    // listed here still shows up, under 'Other'.
    const layout = <(String, List<String>)>[
      (
        'Accounts',
        [
          'User Accounts Report',
          'Organizer Subscription Report',
          'Application Reviews Report',
        ],
      ),
      (
        'Events & Sales',
        [
          'Transaction Report',
          'Revenue Report',
          'Refund Report',
          'Events and Tickets Report',
          'Resale Activity Report',
        ],
      ),
      (
        'Security & Operations',
        [
          'Scanner and Check-in Report',
          'Fraud Alerts Report',
          'Admin Audit Log Report',
        ],
      ),
    ];
    final groups = [
      for (final g in layout)
        (g.$1, reports.where((r) => g.$2.contains(r.$2)).toList()),
    ];
    final known = {for (final g in layout) ...g.$2};
    final other = reports.where((r) => !known.contains(r.$2)).toList();
    if (other.isNotEmpty) groups.add(('Other', other));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export Reports',
          style: orgText(p, size: 20, weight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Exports cover: ${_rangeLabel()} (change it with the range selector above)',
          style: orgText(p, size: 13, color: p.textSecondary),
        ),
        for (final group in groups) ...[
        const SizedBox(height: 20),
        Text(
          group.$1,
          style: orgText(
            p,
            size: 15,
            weight: FontWeight.w700,
            color: p.accentLabel,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 3
                : (constraints.maxWidth >= 640 ? 2 : 1);
            final cardWidth =
                ((constraints.maxWidth - 16 * (columns - 1)) / columns)
                    .floorToDouble();
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final report in group.$2)
                  SizedBox(
                    width: cardWidth,
                    child: AdminCard(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        height: report.$2 == 'User Accounts Report' ? 206 : 168,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.primary.withValues(
                                  alpha: p.isDark ? 0.20 : 0.10,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                report.$1,
                                color: p.accentLabel,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              report.$2,
                              style: orgText(
                                p,
                                size: 14,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report.$3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: orgText(
                                p,
                                size: 12,
                                color: p.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            if (report.$2 == 'User Accounts Report') ...[
                              const SizedBox(height: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: _isExporting
                                    ? null
                                    : () => setState(
                                        () => _approvedOnly = !_approvedOnly,
                                      ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _approvedOnly,
                                        onChanged: _isExporting
                                            ? null
                                            : (v) => setState(
                                                () => _approvedOnly = v ?? false,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Approved only',
                                      style: orgText(
                                        p,
                                        size: 12,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final pdf in const [false, true])
                                  AdminHeaderButton(
                                    icon: pdf
                                        ? Icons.picture_as_pdf_outlined
                                        : Icons.download_outlined,
                                    label: pdf ? 'Export PDF' : 'Export CSV',
                                    onPressed: _isExporting
                                        ? null
                                        : report.$4 == null
                                        ? () => _showMessage(
                                            '${report.$2} is not available yet.',
                                          )
                                        : () => report.$4!(pdf: pdf),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        ],
      ],
    );
  }

  Widget _panel({
    required String title,
    String? trailing,
    required Widget child,
  }) {
    final p = FairTixPalette.of(context);
    return AdminCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: orgText(p, size: 16, weight: FontWeight.w700),
                    ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing,
                      style: orgText(p, size: 12, color: p.textSecondary),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            child,
          ],
        ),
      ),
    );
  }
}
