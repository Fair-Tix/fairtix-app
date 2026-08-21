import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-revenue-report.dart';

/// TODO(backend): "Resale Flags" and tier-level sales breakdowns depend on
/// the Resale Listings / QR Scan Logs collections (see Chapter III Data
/// Dictionary), which don't exist yet in this prototype. Once wired in,
/// replace the empty states below with real aggregates instead of adding
/// more sample numbers here.
class OrganizerAnalyticsSalesScreen extends StatelessWidget {
  const OrganizerAnalyticsSalesScreen({super.key});

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
      body: Column(
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
          _salesByTierCard(tierSales),
          const SizedBox(height: 20),
          _alertsCard(),
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
                              .withOpacity(0.6 + (entry.value * 0.4)),
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
    this.valueColor,
  });

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
              color: AppColors.primaryPurple.withOpacity(0.1),
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
