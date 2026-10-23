import 'package:flutter/material.dart';

import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-login.dart';

/// Shown after the email code is verified (Mahilum design): a clock icon, a
/// three-step progress list and a "Back to Log In" button.
class OrganizerApplicationSubmittedScreen extends StatelessWidget {
  const OrganizerApplicationSubmittedScreen({super.key});

  void _backToLogIn(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OrganizerLoginScreen()),
      (route) => false,
    );
  }

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
                icon: Icons.schedule_rounded,
                color: p.accentLabel,
                background: p.progressTrack,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Application submitted',
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
              'We\u2019ll review your ID and proof of organization. '
              'You\u2019ll get an email once a decision is made.',
              textAlign: TextAlign.center,
              style: orgText(p, size: 14, height: 1.5, color: p.textSecondary),
            ),
            const SizedBox(height: 26),
            const _StepRow(
              label: 'Application received',
              state: _StepState.done,
            ),
            const SizedBox(height: 14),
            const _StepRow(label: 'Admin review', state: _StepState.current),
            const SizedBox(height: 14),
            const _StepRow(label: 'Account approved', state: _StepState.todo),
            const SizedBox(height: 26),
            OrganizerSecondaryButton(
              label: 'Back to Log In',
              onPressed: () => _backToLogIn(context),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, current, todo }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    final Widget marker = switch (state) {
      _StepState.done => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
      _StepState.current => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.primary, width: 2),
        ),
      ),
      _StepState.todo => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.border, width: 2),
        ),
      ),
    };

    return Row(
      children: [
        marker,
        const SizedBox(width: 14),
        Text(
          label,
          style: orgText(
            p,
            size: 14,
            height: 1.3,
            weight: state == _StepState.current
                ? FontWeight.w700
                : FontWeight.w400,
            color: state == _StepState.todo ? p.textSecondary : p.textPrimary,
          ),
        ),
      ],
    );
  }
}
