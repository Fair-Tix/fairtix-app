import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../services/event_repository.dart';
import '../../services/organizer_session.dart';
import 'organizer-scaffold.dart';

/// TODO(backend): Once ticket sales are recorded with real timestamps
/// (Transactions collection - see Chapter III Data Dictionary), replace the
/// per-event summary table below with the true daily revenue trend. For now
/// this screen reports real per-event totals computed from
/// [EventRepository] rather than fabricated daily figures.
class OrganizerRevenueReportScreen extends StatelessWidget {
  const OrganizerRevenueReportScreen({super.key});

  static double _feeRateFor(String? plan) {
    switch (plan) {
      case 'Standard':
        return 0.09;
      case 'Premium':
        return 0.10;
      case 'Basic':
      default:
        return 0.08;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final events = EventRepository.instance.events;
    final plan = OrganizerSession.instance.account?.subscriptionPlan;
    final feeRate = _feeRateFor(plan);

    final gross = EventRepository.instance.totalGrossRevenue;
    final fees = gross * feeRate;
    final net = gross - fees;
    final feePercentLabel = '${(feeRate * 100).toStringAsFixed(0)}%';
    final planLabel = plan == null ? 'no active plan' : '$plan tier';

    return OrganizerScaffold(
      pageTitle: 'Revenue Report',
      activeItem: OrganizerNavItem.analytics,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _StatCard(
                  icon: Icons.paid_outlined,
                  label: 'Gross Revenue',
                  value: '\u20B1${gross.toStringAsFixed(0)}',
                ),
                _StatCard(
                  icon: Icons.remove_circle_outline,
                  label: 'Platform Fees ($feePercentLabel \u2014 $planLabel)',
                  value: '\u20B1${fees.toStringAsFixed(0)}',
                  valueColor: AppColors.dangerRed,
                ),
                _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Net Payout',
                  value: '\u20B1${net.toStringAsFixed(0)}',
                  valueColor: AppColors.successGreen,
                ),
              ];
              if (!isWide) {
                return Column(
                  children: cards
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: c,
                        ),
                      )
                      .toList(),
                );
              }
              return Row(
                children: cards
                    .map(
                      (c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: c,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Revenue by Event', style: AppTextStyles.h3),
                ),
                if (events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: AppColors.textGray,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No revenue yet. Figures will appear here once '
                          'your events start selling tickets.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyGray,
                        ),
                      ],
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF9FAFB),
                      ),
                      columns: const [
                        DataColumn(label: Text('EVENT')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('TICKETS SOLD')),
                        DataColumn(label: Text('GROSS')),
                        DataColumn(label: Text('FEE')),
                        DataColumn(label: Text('NET')),
                      ],
                      rows: events.map((e) {
                        final eventGross = e.grossRevenue;
                        final eventFee = eventGross * feeRate;
                        final eventNet = eventGross - eventFee;
                        return DataRow(
                          cells: [
                            DataCell(Text(e.name, style: AppTextStyles.label)),
                            DataCell(
                              Text(e.status.label, style: AppTextStyles.body),
                            ),
                            DataCell(
                              Text(
                                '${e.ticketsSold}',
                                style: AppTextStyles.body,
                              ),
                            ),
                            DataCell(
                              Text(
                                '\u20B1${eventGross.toStringAsFixed(0)}',
                                style: AppTextStyles.body,
                              ),
                            ),
                            DataCell(
                              Text(
                                '\u20B1${eventFee.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.dangerRed,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '\u20B1${eventNet.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
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
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primaryPurple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyGray, maxLines: 2),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.h2.copyWith(color: valueColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
