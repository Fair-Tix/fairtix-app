import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../services/event_repository.dart';
import '../../services/organizer_session.dart';

/// Per-event revenue totals from [EventRepository] (gross, platform fee,
/// net). Shown inside Analytics so it does not stack a second dashboard.
class OrganizerRevenueReportBody extends StatelessWidget {
  const OrganizerRevenueReportBody({super.key});

  /// Percent label such as 8% or 8.5%. Admin-set rates are not always whole numbers.
  static String _percentLabel(double rate) {
    final percent = rate * 100;
    if (percent == percent.roundToDouble()) {
      return '${percent.toStringAsFixed(0)}%';
    }
    return '${percent.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '')}%';
  }

  static String _peso(double? amount) =>
      amount == null ? '\u2014' : '\u20B1${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final events = EventRepository.instance.events;
    final account = OrganizerSession.instance.account;
    final plan = account?.subscriptionPlan;
    // The fee rate saved on the organizer's own plan (Admin > Platform
    // Settings). Null when there is no active plan: the fee and net are then
    // shown as unknown rather than guessed.
    final feeRate = account?.subscriptionFeeRate;

    final gross = EventRepository.instance.totalGrossRevenue;
    final fees = feeRate == null ? null : gross * feeRate;
    final net = fees == null ? null : gross - fees;
    final feeLabel = feeRate == null
        ? 'Platform Fees (no active plan)'
        : 'Platform Fees (${_percentLabel(feeRate)} \u2014 $plan plan)';

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _StatCard(
                  icon: Icons.paid_outlined,
                  label: 'Gross Revenue',
                  value: _peso(gross),
                ),
                _StatCard(
                  icon: Icons.remove_circle_outline,
                  label: feeLabel,
                  value: _peso(fees),
                  valueColor: AppColors.dangerRed,
                ),
                _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Net Payout',
                  value: _peso(net),
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
                        final eventFee =
                            feeRate == null ? null : eventGross * feeRate;
                        final eventNet =
                            eventFee == null ? null : eventGross - eventFee;
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
                                _peso(eventGross),
                                style: AppTextStyles.body,
                              ),
                            ),
                            DataCell(
                              Text(
                                _peso(eventFee),
                                style: const TextStyle(
                                  color: AppColors.dangerRed,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _peso(eventNet),
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
