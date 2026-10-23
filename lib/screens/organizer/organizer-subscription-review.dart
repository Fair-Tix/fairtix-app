import 'package:flutter/material.dart';

import '../../models/subscription_plan.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';

/// "Confirm your subscription" (Mahilum design): a summary of the chosen plan
/// shown just before the PayMongo payment starts.
///
/// This screen only asks; it pops with `true` when the organizer taps
/// "Confirm Subscription" and `false` for "Change plan" (or the back arrow).
/// [OrganizerSubscriptionPlanScreen] starts the checkout when it gets `true`.
class OrganizerSubscriptionReviewScreen extends StatelessWidget {
  const OrganizerSubscriptionReviewScreen({
    super.key,
    required this.plan,
    this.isRenewal = false,
  });

  final SubscriptionPlan plan;

  /// True when this is the organizer's current plan being bought again.
  final bool isRenewal;

  String _events() => plan.maxEventsPerMonth == null
      ? 'Unlimited'
      : 'Up to ${plan.maxEventsPerMonth} per month';

  String _tickets() => plan.maxTicketsPerDay == null
      ? 'Unlimited'
      : 'Up to ${_withCommas(plan.maxTicketsPerDay!)} per day';

  String _fee() {
    final percent = plan.feeRate * 100;
    final text = percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return '$text% per ticket';
  }

  static String _withCommas(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerAuthPage(
      maxWidth: 520,
      onBack: () => Navigator.of(context).pop(false),
      child: OrganizerCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm your subscription',
              style: orgText(
                p,
                size: 28,
                weight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review your plan before you pay.',
              style: orgText(p, size: 14, color: p.textSecondary),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  _SummaryRow(label: 'Plan', value: '${plan.name} \u2014 Monthly'),
                  _SummaryRow(label: 'Events', value: _events()),
                  _SummaryRow(label: 'Tickets', value: _tickets()),
                  _SummaryRow(label: 'Platform fee', value: _fee()),
                  const _SummaryRow(
                    label: 'Renewal',
                    value: 'Monthly, automatic',
                  ),
                  const SizedBox(height: 4),
                  Divider(height: 1, color: p.border),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Due today',
                        style: orgText(
                          p,
                          size: 17,
                          weight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        plan.priceLabel,
                        style: orgText(
                          p,
                          size: 17,
                          weight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            OrganizerPrimaryButton(
              label: isRenewal ? 'Renew Subscription' : 'Confirm Subscription',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 16),
            Center(
              child: OrganizerTextLink(
                label: 'Change plan',
                size: 14,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: orgText(p, size: 14, height: 1.3, color: p.textSecondary),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: orgText(p, size: 14, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
