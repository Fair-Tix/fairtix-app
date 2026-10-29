import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../theme/fairtix_palette.dart';
import 'organizer-scaffold.dart';
import 'organizer-my-events.dart';

class OrganizerEventCancelledScreen extends StatelessWidget {
  final String eventId;
  final String totalRefunds;

  const OrganizerEventCancelledScreen({
    super.key,
    required this.eventId,
    required this.totalRefunds,
  });

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return OrganizerScaffold(
      pageTitle: 'Event Cancelled',
      activeItem: OrganizerNavItem.myEvents,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.dangerRedBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.help_outline_rounded,
                      color: AppColors.dangerRed, size: 32),
                ),
                const SizedBox(height: 22),
                Text(
                  'Event Cancelled',
                  style: AppTextStyles.h1.copyWith(color: p.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'The event has been successfully cancelled. Refund '
                  'requests have been queued for processing.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyGray.copyWith(
                    height: 1.5,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow(p, 'Event ID', eventId),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: p.border),
                      ),
                      _infoRow(p, 'Total Refunds', totalRefunds),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                PrimaryButton(
                  label: 'Back to My Events',
                  isGradient: true,
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrganizerMyEventsScreen(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(FairTixPalette p, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyGray.copyWith(color: p.textSecondary),
        ),
        Text(value, style: AppTextStyles.label.copyWith(color: p.textPrimary)),
      ],
    );
  }
}