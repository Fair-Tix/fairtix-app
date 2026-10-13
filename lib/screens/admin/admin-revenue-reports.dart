import 'package:flutter/material.dart';

import '../../services/admin_session.dart';
import '../../models/transaction.dart' show formatDateTime;
import '../../services/admin_refund_service.dart';
import '../../services/admin_report_service.dart';
import '../../services/admin_revenue_service.dart';
import '../../services/csv_export.dart';
import '../organizer/app_colors.dart';
import 'admin-accounts.dart';
import 'admin-dashboard.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-login.dart';
import 'admin-organizer-applications.dart';
import 'admin-resale-monitoring.dart';
import 'admin-route.dart';
import 'admin-platform-settings.dart';
import 'admin-profile.dart';

class AdminRevenueReportsScreen extends StatefulWidget {
  const AdminRevenueReportsScreen({super.key});

  @override
  State<AdminRevenueReportsScreen> createState() =>
      _AdminRevenueReportsScreenState();
}

class _AdminRevenueReportsScreenState extends State<AdminRevenueReportsScreen> {
  String _range = 'This Month';
  List<PlanRevenue> _plans = [];
  bool _isLoading = true;
  String? _errorMessage;
  List<RefundEntry> _refunds = [];
  bool _isLoadingRefunds = true;
  String? _refundError;
  DateTimeRange? _customRange;
  bool _isExporting = false;

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
    return '${d(from)} – ${d(to.subtract(const Duration(days: 1)))}';
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

  Future<void> _exportReport(
    String slug,
    Future<String> Function(DateTime? from, DateTime? to) build,
  ) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final (from, to) = _rangeBounds();
      final csv = await build(from, to);
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final fileName =
          'fairtix_${slug}_${now.year}-${two(now.month)}-${two(now.day)}.csv';
      final saved = await saveCsvFile(fileName: fileName, csv: csv);
      if (!mounted) return;
      if (saved) _showMessage('Report exported ($fileName).');
    } on AdminReportException catch (e) {
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
    (from, to) =>
        AdminReportService.instance.transactionReportCsv(from: from, to: to),
  );

  Future<void> _exportRevenue() => _exportReport(
    'revenue',
    (from, to) =>
        AdminReportService.instance.revenueReportCsv(from: from, to: to),
  );

  Future<void> _exportRefunds() => _exportReport(
    'refunds',
    (from, to) =>
        AdminReportService.instance.refundReportCsv(from: from, to: to),
  );

  @override
  void initState() {
    super.initState();
    _loadRevenue();
    _loadRefunds();
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

  Future<void> _processRefund(RefundEntry refund) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark refund as processed?'),
        content: Text(
          'Record that ${_money(refund.amount)} was refunded to '
          '${refund.buyerName}. This does not send money by itself — '
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
      await Future.wait([_loadRefunds(), _loadRevenue()]);
    } on AdminRefundException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    }
  }

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

  static const _items = [
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

  void _navigate(int index) {
    final pages = <int, Widget>{
      0: const AdminDashboardScreen(),
      1: const AdminOrganizerApplicationsScreen(),
      2: const AdminAccountsScreen(),
      3: const AdminEventsTicketsScreen(),
      4: const AdminResaleMonitoringScreen(),
      5: const AdminFraudAlertsScreen(),
      7: const AdminPlatformSettingsScreen(),
      8: const AdminProfileScreen(),
    };
    final page = pages[index];
    if (page != null) {
      Navigator.pushReplacement(context, adminPageRoute(page));
    }
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
    final currentEmail =
        AdminSession.instance.currentEmail ?? 'admin@fairtix.com';

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
            for (var index = 0; index < _items.length; index++)
              _SidebarItem(
                icon: _items[index].$1,
                label: _items[index].$2,
                selected: index == 6,
                onTap: () => _navigate(index),
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
                    child: Icon(
                      Icons.person,
                      size: 17,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin', style: AppTextStyles.label),
                        Text(
                          currentEmail,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _confirmLogout,
                    icon: const Icon(
                      Icons.logout,
                      size: 17,
                      color: AppColors.textGray,
                    ),
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
          const Text('Revenue & Reports', style: AppTextStyles.label),
          const Spacer(),
          SizedBox(
            width: isWide ? 270 : 130,
            height: 32,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users, events...',
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
          const SizedBox(width: 16),
          const Icon(
            Icons.notifications_none,
            size: 19,
            color: AppColors.textGray,
          ),
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
            const SizedBox(width: 10),
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
        _buildSummaryCards(revenue, fees, payouts, hasData),
        const SizedBox(height: 18),
        _buildFeesByPlan(),
        const SizedBox(height: 18),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDailyRevenue(hasData)),
              const SizedBox(width: 18),
              Expanded(child: _buildBreakdown(revenue, hasData)),
            ],
          )
        else ...[
          _buildDailyRevenue(hasData),
          const SizedBox(height: 18),
          _buildBreakdown(revenue, hasData),
        ],
        const SizedBox(height: 18),
        _buildMonthlyBreakdown(hasData),
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
                  color: _range == range
                      ? AppColors.primaryPurple
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    if (range == 'Custom Range') ...[
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: AppColors.textGray,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      range,
                      style: TextStyle(
                        color: _range == range
                            ? Colors.white
                            : AppColors.textGray,
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

  Widget _buildSummaryCards(
    double revenue,
    double fees,
    double payouts,
    bool hasData,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          (
            Icons.payments_outlined,
            AppColors.primaryPurple,
            'Total Revenue',
            _money(revenue),
            hasData ? 'From recorded ticket sales' : 'No sales data yet',
          ),
          (
            Icons.percent_outlined,
            const Color(0xFFB05BFF),
            'Platform Fees',
            _money(fees),
            hasData ? 'Per plan: 8% / 9% / 10%' : 'No fee data yet',
          ),
          (
            Icons.sell_outlined,
            const Color(0xFF10B981),
            'Net Payouts',
            _money(payouts),
            hasData ? 'After platform fees' : 'No payout data yet',
          ),
        ];
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: constraints.maxWidth > 760
                      ? (constraints.maxWidth - 32) / 3
                      : constraints.maxWidth,
                  child: Container(
                    height: 116,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: card.$2.withValues(alpha: 0.12),
                              child: Icon(card.$1, size: 16, color: card.$2),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              card.$3,
                              style: const TextStyle(
                                color: AppColors.textGray,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          card.$4,
                          style: TextStyle(
                            color: card.$2,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          card.$5,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
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
    return _panel(
      title: 'Platform Fees by Plan',
      trailing: _isLoading ? 'Loading...' : _rangeLabel(),
      child: Column(
        children: [
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(child: Text('PLAN', style: _headerStyle)),
                Expanded(child: Text('FEE RATE', style: _headerStyle)),
                Expanded(child: Text('TICKETS', style: _headerStyle)),
                Expanded(child: Text('TICKET REVENUE', style: _headerStyle)),
                Expanded(child: Text('PLATFORM FEES', style: _headerStyle)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final plan in _plans.isEmpty
              ? [
                  for (final (name, rate) in AdminRevenueService.plans)
                    PlanRevenue(
                      plan: name,
                      rate: rate,
                      tickets: 0,
                      gross: 0,
                      fees: 0,
                      net: 0,
                    ),
                ]
              : _plans)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.plan,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      plan.rateLabel,
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${plan.tickets}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _money(plan.gross),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _money(plan.fees),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRefundLog() {
    final pending = _refunds.where((r) => !r.isProcessed).length;
    return _panel(
      title: 'Refund Log',
      trailing: _isLoadingRefunds
          ? 'Loading...'
          : '${_refunds.length} total • $pending pending',
      child: Column(
        children: [
          const Divider(height: 1),
          if (_refundError != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _refundError!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadRefunds,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (!_isLoadingRefunds && _refunds.isEmpty)
            const SizedBox(
              height: 110,
              child: Center(
                child: Text(
                  'No refunds yet. Refunds appear here when an event is canceled.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 11),
                ),
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('DATE', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('EVENT', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('BUYER', style: _headerStyle)),
                  Expanded(child: Text('AMOUNT', style: _headerStyle)),
                  Expanded(child: Text('STATUS', style: _headerStyle)),
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
                    Expanded(
                      flex: 2,
                      child: Text(
                        formatDateTime(refund.createdAt),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        refund.eventTitle,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        refund.buyerName,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _money(refund.amount),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: refund.isProcessed
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            refund.statusLabel,
                            style: TextStyle(
                              color: refund.isProcessed
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFB45309),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: refund.isProcessed
                          ? const SizedBox.shrink()
                          : TextButton(
                              onPressed: () => _processRefund(refund),
                              child: const Text(
                                'Mark Processed',
                                style: TextStyle(fontSize: 9),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDailyRevenue(bool hasData) {
    return _panel(
      title: 'Daily Revenue - Last 30 Days',
      trailing: 'No recorded sales',
      child: SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 42, color: const Color(0xFFD9D7E4)),
              const SizedBox(height: 10),
              Text(
                hasData
                    ? 'Daily revenue will appear here.'
                    : 'No revenue data yet',
                style: const TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'This chart will use ticket sales from the backend.',
                style: TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdown(double revenue, bool hasData) {
    return _panel(
      title: 'Revenue Breakdown',
      child: SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.donut_large_outlined,
                size: 54,
                color: hasData
                    ? AppColors.primaryPurple
                    : const Color(0xFFD9D7E4),
              ),
              const SizedBox(height: 10),
              Text(
                hasData ? _money(revenue) : '₱0',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Total recorded revenue',
                style: TextStyle(color: AppColors.textGray, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyBreakdown(bool hasData) {
    return _panel(
      title: 'Monthly Breakdown',
      trailing: '${DateTime.now().year}',
      child: Column(
        children: [
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(child: Text('MONTH', style: _headerStyle)),
                Expanded(child: Text('TICKET REVENUE', style: _headerStyle)),
                Expanded(child: Text('PLATFORM FEES', style: _headerStyle)),
                Expanded(child: Text('NET PAYOUTS', style: _headerStyle)),
                Text('GROWTH', style: _headerStyle),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 130,
            child: Center(
              child: Text(
                hasData
                    ? 'Monthly figures will appear after sales are recorded.'
                    : 'No monthly revenue data yet',
                style: const TextStyle(color: AppColors.textGray, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
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
        Icons.check_circle_outline,
        'Attendance Report',
        'QR scan logs and attendance rates by event and gate.',
        () => _showMessage('Attendance reports are not available yet.'),
      ),
      (
        Icons.sync_outlined,
        'Resale Activity Report',
        'Resale listings, flagged violations, and resolved cases.',
        () => _showMessage('Resale activity reports are not available yet.'),
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
            children: reports
                .map(
                  (report) => SizedBox(
                    width: constraints.maxWidth > 760
                        ? (constraints.maxWidth - 32) / 3
                        : constraints.maxWidth,
                    child: Container(
                      height: 160,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFEDE7FF),
                            child: Icon(
                              report.$1,
                              color: AppColors.primaryPurple,
                              size: 19,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            report.$2,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            report.$3,
                            style: const TextStyle(
                              color: AppColors.textGray,
                              fontSize: 9,
                              height: 1.3,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _isExporting ? null : report.$4,
                            icon: const Icon(Icons.download_outlined, size: 13),
                            label: const Text(
                              'Export CSV',
                              style: TextStyle(fontSize: 9),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryPurple,
                              side: const BorderSide(
                                color: AppColors.primaryPurple,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _panel({
    required String title,
    String? trailing,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.h3)),
                if (trailing != null)
                  Text(
                    trailing,
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  String _money(double amount) => '₱${amount.toStringAsFixed(2)}';

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to Log Out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }
}

const _headerStyle = TextStyle(
  color: AppColors.textGray,
  fontSize: 9,
  fontWeight: FontWeight.w700,
);

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
        decoration: BoxDecoration(
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(
          Icons.confirmation_number_outlined,
          color: Colors.white,
          size: 14,
        ),
      ),
      const SizedBox(width: 6),
      const Text(
        'FairTix',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
        ),
      ),
      const SizedBox(width: 3),
      const Text(
        'ADMIN',
        style: TextStyle(fontSize: 8, color: AppColors.textGray),
      ),
    ],
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
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
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textDark,
              ),
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
