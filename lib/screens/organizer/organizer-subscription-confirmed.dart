import 'package:flutter/material.dart';

import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import 'app_colors.dart' show formatFriendlyDate;
import 'organizer-dashboard.dart';

/// Shown after a subscription payment is confirmed.
///
/// There is no Mahilum design for this exact screen (the design's
/// "Subscription Confirmation" is the pre-payment review, see
/// `organizer-subscription-review.dart`), so it reuses the same card style:
/// green tick, plan summary and a "Go to Dashboard" button.
class OrganizerSubscriptionConfirmedScreen extends StatelessWidget {
  final String planName;
  final String price;
  final DateTime renewsAt;

  /// The benefit lines the admin wrote for this plan (the same ones shown on
  /// the plan card). Empty falls back to a single generic line.
  final List<String> features;

  const OrganizerSubscriptionConfirmedScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.renewsAt,
    this.features = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final shownFeatures = features.isEmpty
        ? const ['All features of your plan are now unlocked']
        : features.take(4).toList();

    return OrganizerAuthPage(
      maxWidth: 520,
      child: OrganizerCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: OrganizerStatusIcon(
                icon: Icons.check_rounded,
                color: p.success,
                background: p.successSurface,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Subscription active',
              textAlign: TextAlign.center,
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
              'Your $planName plan is unlocked. Start creating your next '
              'event.',
              textAlign: TextAlign.center,
              style: orgText(p, size: 14, height: 1.5, color: p.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$planName \u2014 Monthly',
                        style: orgText(p, size: 16, weight: FontWeight.w800),
                      ),
                      Text(
                        price,
                        style: orgText(p, size: 16, weight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Next renewal: ${formatFriendlyDate(renewsAt)}',
                    style: orgText(p, size: 13, color: p.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: p.border),
                  const SizedBox(height: 14),
                  for (final line in shownFeatures)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_rounded, size: 18, color: p.success),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              line,
                              style: orgText(p, size: 13.5, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OrganizerPrimaryButton(
              label: 'Go to Dashboard',
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizerDashboardScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
