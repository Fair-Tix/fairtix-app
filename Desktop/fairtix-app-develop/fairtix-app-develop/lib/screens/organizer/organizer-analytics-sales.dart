import 'dart:async';

import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-revenue-report.dart';

/// Sales overview for the signed-in organizer.
///
/// Loads fresh data on open, then keeps itself current: a Supabase realtime
/// listener on `ticket_tiers` refreshes after every purchase/refund, with a
/// 20-second poll as a safety net (e.g. if realtime isn't enabled on the
/// table). Per-tier sold / remaining / revenue come from
/// `ticket_tiers.total_quantity - remaining_quantity`, which
/// `_do_ticket_purchase` decrements on each sale.
///
/// TODO(backend): "Resale Flags" depend on resale/scan data and stay as an
/// empty state until those are wired in.
class OrganizerAnalyticsSalesScreen extends StatefulWidget {
  const OrganizerAnalyticsSalesScreen({super.key});

  @override
  State<OrganizerAnalyticsSalesScreen> createState() =>
      _OrganizerAnalyticsSalesScreenState();
}

class _OrganizerAnalyticsSalesScreenState
    extends State<OrganizerAnalyticsSalesScreen> {
  bool _isLoading = true;
  String? _loadError;
  VoidCallback? _stopListening;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    try {
      _stopListening = EventRepository.instance.listenForSales(_silentReload);
    } catch (_) {
      // Realtime unavailable - the poll below still keeps the numbers fresh.
    }
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _silentReload());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _stopListening?.call();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await EventRepository.instance.refresh();
    } on EventRepositoryException catch (e) {
      _loadError = e.message;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _silentReload() async {
    try {
      await EventRepository.instance.refresh();
    } on EventRepositoryException {
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final events = EventRepository.instance.events;

    final tierSales = <String, double>{};
    final maxTierQuantity = <String, int>{};
    for (final event in events) {
      for (final tier in event.tiers) {
        if (tier.quantity <= 0) continue;
        final ratio = tier.sold / tier.quantity;
        final key = tier.name;
        if (!tierSales.containsKey(key) || ratio > tierSales[key]!) {
          tierSales[key] = ratio.clamp(0, 1).toDouble();
        }
        maxTierQuantity[key] = tier.quantity;
      }
    }

    return OrganizerScaffold(
      pageTitle: 'Sales Overview',
      activeItem: OrganizerNavItem.analytics,
      topBarTrailing: TextButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OrganizerRevenueReportScreen(),
            ),
          );
        },
        icon: const Icon(Icons.receipt_long_outlined,
            size: 18, color: AppColors.primaryPurple),
        label: const Text('Revenue Report',
            style: TextStyle(color: AppColors.primaryPurple)),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          : _loadError != null
          ? Column(
              children: [
                Text(_loadError!,
                    style: const TextStyle(color: AppColors.dangerRed)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ],
            )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _StatCard(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Tickets Sold',
                  value: '${EventRepository.instance.totalTicketsSold}',
                ),
                _StatCard(
                  icon: Icons.paid_outlined,
                  label: 'Total Revenue',
                  value:
                      '\u20B1${EventRepository.instance.totalGrossRevenue.toStringAsFixed(0)}',
                ),
                _StatCard(
                  icon: Icons.event_available_outlined,
                  label: 'Active Events',
                  value:
                      '${events.where((e) => e.status == EventStatus.published).length}',
                ),
              ];
              if (!isWide) {
                return Column(
                  children: cards
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: c,
                          ))
                      .toList(),
                );
              }
              return Row(
                children: cards
                    .map((c) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: c,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          _inventoryCard(events),
          const SizedBox(height: 20),
          _salesByTierCard(tierSales),
          const SizedBox(height: 20),
          _alertsCard(),
        ],
      ),
    );
  }

  /// Per-event, per-tier table: tickets sold, remaining and revenue.
  Widget _inventoryCard(List<OrganizerEvent> events) {
    final rows = events.where((e) => e.tiers.isNotEmpty).toList();
    return _card(
      title: 'Ticket Sales & Inventory',
      child: rows.isEmpty
          ? _emptyRow('No ticket tiers yet. Create an event to see sales here.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in rows) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, top: 4),
                    child: Text(
                      e.isMultiDay
                          ? '${e.name}  \u2022  all ${e.dayCount} day${e.dayCount == 1 ? '' : 's'}'
                          : e.name,
                      style: AppTextStyles.label,
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 38,
                      dataRowMaxHeight: 42,
                      columns: const [
                        DataColumn(label: Text('TIER')),
                        DataColumn(label: Text('PRICE'), numeric: true),
                        DataColumn(label: Text('SOLD'), numeric: true),
                        DataColumn(label: Text('REMAINING'), numeric: true),
                        DataColumn(label: Text('REVENUE'), numeric: true),
                      ],
                      rows: [
                        for (final t in e.tiers)
                          DataRow(cells: [
                            DataCell(Text(t.name)),
                            DataCell(Text('\u20B1${t.price.toStringAsFixed(0)}')),
                            DataCell(Text('${t.sold} / ${t.quantity}')),
                            DataCell(Text(
                              '${t.remaining}',
                              style: TextStyle(
                                color: t.remaining == 0
                                    ? AppColors.dangerRed
                                    : AppColors.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                            DataCell(Text(
                                '\u20B1${t.grossRevenue.toStringAsFixed(0)}')),
                          ]),
                        DataRow(cells: [
                          const DataCell(Text('Total',
                              style: TextStyle(fontWeight: FontWeight.w800))),
                          const DataCell(Text('')),
                          DataCell(Text('${e.ticketsSold} / ${e.ticketsTotal}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                          DataCell(Text('${e.ticketsRemaining}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                          DataCell(Text(
                              '\u20B1${e.grossRevenue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _salesByTierCard(Map<String, double> tierSales) {
    const maxBarHeight = 180.0;
    return _card(
      title: 'Sales by Tier',
      child: tierSales.isEmpty
          ? _emptyRow('No ticket tiers with sales yet.')
          : SizedBox(
              height: 220,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: tierSales.entries.map((entry) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 44,
                        height: maxBarHeight * entry.value,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple
                              .withValues(alpha: 0.6 + (entry.value * 0.4)),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(entry.key, style: AppTextStyles.label),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _alertsCard() {
    return _card(
      title: 'Inventory Alerts & Resale Flags',
      child: _emptyRow(
        'No alerts right now. Fraud and resale monitoring will appear here '
        'once resale and scan data are available.',
      ),
    );
  }

  Widget _emptyRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.bar_chart_rounded,
              size: 32, color: AppColors.textGray),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyGray,
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  }) : valueColor = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primaryPurple, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodyGray),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.h2.copyWith(color: valueColor)),
            ],
          ),
        ],
      ),
    );
  }
}
