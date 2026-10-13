import 'package:flutter/material.dart';

import '../../services/admin_overview_service.dart';
import '../../services/admin_refund_service.dart';
import '../../services/admin_report_service.dart';
import '../../services/admin_resale_service.dart';
import '../../services/admin_revenue_service.dart';
import '../../services/csv_export.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../organizer/app_colors.dart';

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
  State<AdminRevenueReportsScreen> createState() => _AdminRevenueReportsScreenState();
}

class _AdminRevenueReportsScreenState extends State<AdminRevenueReportsScreen> {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

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
        return (DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
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
      final plans = await AdminRevenueService.instance.fetchByPlan(from: from, to: to);
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
      final monthly = await AdminOverviewService.instance.fetchMonthly(DateTime.now().year);
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

  Future<void> _refreshAll() => Future.wait([_loadRevenue(), _loadRefunds(), _loadCharts()]);

  // ── refunds ──────────────────────────────────────────────────────────

  Future<void> _processRefund(RefundEntry refund) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark refund as processed?'),
        content: Text(
          'Record that ${formatPeso(refund.amount)} was refunded to '
          '${refund.buyerName}. This does not send money by itself \u2014 '
          'issue the refund in PayMongo first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Processed'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await AdminRefundService.instance.markProcessed(refund.id);
      if (!mounted) return;
      _showMessage('Refund marked as processed.');
      await _refreshAll();
    } on AdminRefundException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    }
  }

  // ── exports ──────────────────────────────────────────────────────────

  Future<void> _exportReport(
    String slug,
    Future<String> Function(DateTime? from, DateTime? to) build,
  ) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final (from, to) = _rangeBounds();
      final csv = await build(from, to);
      final fileName = 'fairtix_${slug}_${formatIsoDate(DateTime.now())}.csv';
      final saved = await saveCsvFile(fileName: fileName, csv: csv);
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

  Future<void> _exportTransactions() => _exportReport(
    'transactions',
    (from, to) => AdminReportService.instance.transactionReportCsv(from: from, to: to),
  );

  Future<void> _exportRevenue() => _exportReport(
    'revenue',
    (from, to) => AdminReportService.instance.revenueReportCsv(from: from, to: to),
  );

  Future<void> _exportRefunds() => _exportReport(
    'refunds',
    (from, to) => AdminReportService.instance.refundReportCsv(from: from, to: to),
  );

  Future<void> _exportResale() => _exportReport('resale_activity', (from, to) async {
    final listings = await AdminResaleService.instance.fetchListings();
    final inRange = listings.where((l) {
      if (from != null && l.listedAt.isBefore(from)) return false;
      if (to != null && !l.listedAt.isBefore(to)) return false;
      return true;
    }).toList();
    return resaleListingsToCsv(inRange);
  });

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final revenue = _plans.fold<double>(0, (sum, p) => sum + p.gross);
    final fees = _plans.fold<double>(0, (sum, p) => sum + p.fees);
    final payouts = _plans.fold<double>(0, (sum, p) => sum + p.net);
    final hasData = _plans.any((p) => p.tickets > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Revenue & Reports', style: AppTextStyles.h2),
                  SizedBox(height: 3),
                  Text(
                    'Track platform earnings and export financial data',
                    style: AppTextStyles.bodyGray,
                  ),
                ],
              ),
            ),
            if (isWide) _buildRangeControls(),
            IconButton(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh',
            ),
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportRevenue,
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export CSV', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
              ),
            ),
          ],
        ),
        if (!isWide) ...[const SizedBox(height: 12), _buildRangeControls()],
        const SizedBox(height: 18),
        if (_errorMessage != null) ...[
          _buildErrorBanner(),
          const SizedBox(height: 12),
        ],
        AdminSummaryRow(
          cards: [
            AdminSummaryCard(
              icon: Icons.payments_outlined,
              color: AppColors.primaryPurple,
              label: 'Total Revenue',
              value: formatPeso(revenue),
              caption: hasData ? 'From recorded ticket sales' : 'No sales data yet',
            ),
            AdminSummaryCard(
              icon: Icons.percent_outlined,
              color: const Color(0xFFB05BFF),
              label: 'Platform Fees',
              value: formatPeso(fees),
              caption: hasData ? 'Per plan: 8% / 9% / 10%' : 'No fee data yet',
            ),
            AdminSummaryCard(
              icon: Icons.sell_outlined,
              color: AppColors.successGreen,
              label: 'Net Payouts',
              value: formatPeso(payouts),
              caption: hasData ? 'After platform fees' : 'No payout data yet',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildFeesByPlan(),
        const SizedBox(height: 18),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDailyRevenue()),
              const SizedBox(width: 18),
              Expanded(child: _buildBreakdown(revenue)),
            ],
          )
        else ...[
          _buildDailyRevenue(),
          const SizedBox(height: 18),
          _buildBreakdown(revenue),
        ],
        const SizedBox(height: 18),
        _buildMonthlyBreakdown(),
        const SizedBox(height: 18),
        _buildRefundLog(),
        const SizedBox(height: 22),
        _buildExportReports(),
      ],
    );
  }

  Widget _buildRangeControls() {
    return Container(
      height: 34,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final range in ['This Week', 'This Month', 'Custom Range'])
            InkWell(
              onTap: () => _selectRange(range),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _range == range ? AppColors.primaryPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    if (range == 'Custom Range') ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: _range == range ? Colors.white : AppColors.textGray,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      range,
                      style: TextStyle(
                        color: _range == range ? Colors.white : AppColors.textGray,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11),
            ),
          ),
          TextButton(onPressed: _loadRevenue, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildFeesByPlan() {
    final plans = _plans.isEmpty
        ? [
            for (final (name, rate) in AdminRevenueService.plans)
              PlanRevenue(plan: name, rate: rate, tickets: 0, gross: 0, fees: 0, net: 0),
          ]
        : _plans;
    return _panel(
      title: 'Platform Fees by Plan',
      trailing: _isLoading ? 'Loading...' : _rangeLabel(),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(child: Text('PLAN', style: adminHeaderStyle)),
                Expanded(child: Text('FEE RATE', style: adminHeaderStyle)),
                Expanded(child: Text('TICKETS', style: adminHeaderStyle)),
                Expanded(child: Text('TICKET REVENUE', style: adminHeaderStyle)),
                Expanded(child: Text('PLATFORM FEES', style: adminHeaderStyle)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final plan in plans)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(child: Text(plan.plan, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                  Expanded(
                    child: Text(
                      plan.rateLabel,
                      style: const TextStyle(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text('${plan.tickets}', style: const TextStyle(fontSize: 11))),
                  Expanded(child: Text(formatPeso(plan.gross), style: const TextStyle(fontSize: 11))),
                  Expanded(child: Text(formatPeso(plan.fees), style: const TextStyle(fontSize: 11))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chartSpinner() => const SizedBox(
    height: 220,
    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
  );

  Widget _buildDailyRevenue() {
    final total = _daily.fold<double>(0, (sum, d) => sum + d.gross);
    final maxGross = _daily.fold<double>(0, (m, d) => d.gross > m ? d.gross : m);

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                                heightFactor: d.gross <= 0 ? 0.012 : (d.gross / maxGross).clamp(0.03, 1.0).toDouble(),
                                widthFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: d.gross > 0 ? AppColors.primaryPurple : AppColors.borderLight,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(formatAdminDate(_daily.first.day), style: const TextStyle(color: AppColors.textGray, fontSize: 9)),
                  const Spacer(),
                  Text(formatAdminDate(_daily.last.day), style: const TextStyle(color: AppColors.textGray, fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return _panel(
      title: 'Daily Revenue \u2013 Last 30 Days',
      trailing: (_isLoadingCharts || _chartsError != null) ? null : '${formatPeso(total)} total',
      child: body,
    );
  }

  Widget _buildBreakdown(double revenue) {
    return _panel(
      title: 'Revenue Breakdown by Plan',
      trailing: _isLoading ? null : formatPeso(revenue),
      child: _isLoading
          ? _chartSpinner()
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  for (final plan in _plans)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${plan.plan} (${plan.rateLabel} fee)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${(plan.gross / revenue * 100).round()}%',
                                style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: plan.gross / revenue,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFF0EEFA),
                              color: AppColors.primaryPurple,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatPeso(plan.gross)} \u2022 ${plan.tickets} ticket${plan.tickets == 1 ? '' : 's'}',
                            style: const TextStyle(color: AppColors.textGray, fontSize: 10),
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
      if (text.startsWith('+')) return AppColors.successGreen;
      if (text.startsWith('-')) return AppColors.dangerRed;
      return AppColors.textGray;
    }

    final Widget body;
    if (_isLoadingCharts) {
      body = _chartSpinner();
    } else if (_chartsError != null) {
      body = AdminErrorBox(message: _chartsError!, onRetry: _loadCharts);
    } else if (!hasSales) {
      body = AdminEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No sales recorded in $year yet',
        hint: 'Monthly figures will appear here once tickets are sold.',
      );
    } else {
      body = Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('MONTH', style: adminHeaderStyle)),
                Expanded(flex: 2, child: Text('TICKET REVENUE', style: adminHeaderStyle)),
                Expanded(flex: 2, child: Text('PLATFORM FEES', style: adminHeaderStyle)),
                Expanded(flex: 2, child: Text('NET PAYOUTS', style: adminHeaderStyle)),
                Expanded(child: Text('GROWTH', style: adminHeaderStyle)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < months.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      _monthNames[months[i].month - 1],
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(flex: 2, child: Text(formatPeso(months[i].gross), style: const TextStyle(fontSize: 11))),
                  Expanded(flex: 2, child: Text(formatPeso(months[i].fees), style: const TextStyle(fontSize: 11))),
                  Expanded(flex: 2, child: Text(formatPeso(months[i].net), style: const TextStyle(fontSize: 11))),
                  Expanded(
                    child: Text(
                      growth(i),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: growthColor(growth(i))),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return _panel(title: 'Monthly Breakdown', trailing: '$year', child: body);
  }

  Widget _buildRefundLog() {
    final pending = _refunds.where((r) => !r.isProcessed).length;
    final Widget body;
    if (_refundError != null) {
      body = AdminErrorBox(message: _refundError!, onRetry: _loadRefunds);
    } else if (_isLoadingRefunds) {
      body = const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    } else if (_refunds.isEmpty) {
      body = const AdminEmptyState(
        icon: Icons.assignment_return_outlined,
        title: 'No refunds yet',
        hint: 'Refunds appear here when an event is canceled.',
      );
    } else {
      body = Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('DATE', style: adminHeaderStyle)),
                Expanded(flex: 2, child: Text('EVENT', style: adminHeaderStyle)),
                Expanded(flex: 2, child: Text('BUYER', style: adminHeaderStyle)),
                Expanded(child: Text('AMOUNT', style: adminHeaderStyle)),
                Expanded(child: Text('STATUS', style: adminHeaderStyle)),
                SizedBox(width: 96),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final refund in _refunds) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(formatAdminDateTime(refund.createdAt), style: const TextStyle(fontSize: 10))),
                  Expanded(flex: 2, child: Text(refund.eventTitle, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  Expanded(flex: 2, child: Text(refund.buyerName, style: const TextStyle(fontSize: 10))),
                  Expanded(child: Text(formatPeso(refund.amount), style: const TextStyle(fontSize: 10))),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: refund.isProcessed
                          ? AdminBadge.success(refund.statusLabel)
                          : AdminBadge.warning(refund.statusLabel),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: refund.isProcessed
                        ? const SizedBox.shrink()
                        : TextButton(
                            onPressed: () => _processRefund(refund),
                            child: const Text('Mark Processed', style: TextStyle(fontSize: 9)),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ],
      );
    }

    return _panel(
      title: 'Refund Log',
      trailing: _isLoadingRefunds ? 'Loading...' : '${_refunds.length} total \u2022 $pending pending',
      child: body,
    );
  }

  Widget _buildExportReports() {
    final reports = <(IconData, String, String, VoidCallback?)>[
      (
        Icons.receipt_long_outlined,
        'Transaction Report',
        'Every purchase and resale with buyer, event, tier, amount, fee, and status.',
        _exportTransactions,
      ),
      (
        Icons.payments_outlined,
        'Revenue Report',
        'Platform fees per organizer plan (8% / 9% / 10%) with gross, fee, and net totals.',
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
        'Every resale listing with seller, event, price versus original, and status.',
        _exportResale,
      ),
      (
        Icons.check_circle_outline,
        'Attendance Report',
        'QR scan logs and attendance rates by event and gate.',
        () => _showMessage('Attendance reports are not available yet.'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Export Reports', style: AppTextStyles.h3),
        const SizedBox(height: 4),
        Text(
          'Exports cover: ${_rangeLabel()} (change it with the range selector above)',
          style: const TextStyle(color: AppColors.textGray, fontSize: 10),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final report in reports)
                SizedBox(
                  width: constraints.maxWidth > 760
                      ? ((constraints.maxWidth - 32) / 3).floorToDouble()
                      : constraints.maxWidth,
                  child: AdminCard(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 128,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFEDE7FF),
                            child: Icon(report.$1, color: AppColors.primaryPurple, size: 19),
                          ),
                          const SizedBox(height: 10),
                          Text(report.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(
                            report.$3,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textGray, fontSize: 9, height: 1.3),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _isExporting ? null : report.$4,
                            icon: const Icon(Icons.download_outlined, size: 13),
                            label: const Text('Export CSV', style: TextStyle(fontSize: 9)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryPurple,
                              side: const BorderSide(color: AppColors.primaryPurple),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel({required String title, String? trailing, required Widget child}) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.h3)),
                if (trailing != null)
                  Text(trailing, style: const TextStyle(color: AppColors.textGray, fontSize: 10)),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}
