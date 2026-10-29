import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../theme/fairtix_palette.dart';
import 'organizer-scaffold.dart';
import 'organizer-dashboard.dart';
import 'organizer-my-events.dart';

class OrganizerEventCreatedScreen extends StatelessWidget {
  final String eventName;
  final String date;
  final String venue;
  final bool isMultiDay;

  const OrganizerEventCreatedScreen({
    super.key,
    required this.eventName,
    required this.date,
    required this.venue,
    this.isMultiDay = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return OrganizerScaffold(
      pageTitle: 'Event Published',
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
                    color: AppColors.successGreenBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.successGreen,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Event Published!',
                  style: AppTextStyles.h1.copyWith(color: p.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  isMultiDay
                      ? 'Your multi-day event is now live \u2014 a page was '
                            'generated for each day, and attendees can start '
                            'purchasing tickets.'
                      : 'Your event is now live and attendees can start '
                            'purchasing tickets.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyGray.copyWith(
                    height: 1.5,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow(p, 'Event', eventName),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: p.border),
                      ),
                      _infoRow(p, 'Date', date),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: p.border),
                      ),
                      _infoRow(p, 'Venue', venue),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                PrimaryButton(
                  label: 'View Event Page',
                  isGradient: true,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrganizerMyEventsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlineButtonWidget(
                  label: 'Go to Dashboard',
                  textColor: p.textPrimary,
                  borderColor: p.border,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrganizerDashboardScreen(),
                      ),
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.label.copyWith(color: p.textPrimary),
          ),
        ),
      ],
    );
  }
}
