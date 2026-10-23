import 'package:flutter/material.dart';

import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-subscription-plan.dart';

/// Shown once an organizer's application has been approved (Mahilum design:
/// green tick, "You're approved", and a single "Choose a Plan" button).
///
/// TODO(backend): Not yet reachable through app navigation because there is
/// no admin-approval notification in this prototype. Once organizer
/// applications are approved server-side (e.g. via the Admin panel), route
/// the organizer here - typically from a login/notification check - instead
/// of leaving it as a dead-end screen.
class OrganizerAccountApprovedScreen extends StatelessWidget {
  const OrganizerAccountApprovedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

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
              'You\u2019re approved',
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
              'Your organizer account is active. Choose a subscription plan '
              'to start creating events.',
              textAlign: TextAlign.center,
              style: orgText(p, size: 14, height: 1.5, color: p.textSecondary),
            ),
            const SizedBox(height: 26),
            OrganizerPrimaryButton(
              label: 'Choose a Plan',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizerSubscriptionPlanScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
