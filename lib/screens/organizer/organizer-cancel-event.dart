import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-event-cancelled.dart';
import 'organizer-my-events.dart';

class OrganizerCancelEventScreen extends StatelessWidget {
  final String eventId;

  const OrganizerCancelEventScreen({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    final event = EventRepository.instance.getById(eventId);

    if (event == null) {
      return OrganizerScaffold(
        pageTitle: 'Cancel Event',
        activeItem: OrganizerNavItem.myEvents,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: AppColors.textGray),
              const SizedBox(height: 12),
              const Text('This event could not be found.',
                  style: AppTextStyles.h3),
              const SizedBox(height: 16),
              OutlineButtonWidget(
                label: 'Back to My Events',
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizerMyEventsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return OrganizerScaffold(
      pageTitle: 'Cancel Event',
      activeItem: OrganizerNavItem.myEvents,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
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
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.dangerRed, size: 32),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Cancel This Event?',
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'This action cannot be undone. All ticket holders will be '
                  'notified and refunds will be processed automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryPurple.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Event', event.name),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: AppColors.borderLight),
                      ),
                      _infoRow('Venue', event.venue),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: AppColors.borderLight),
                      ),
                      _infoRow('Tickets Sold', '${event.ticketsSold}'),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                PrimaryButton(
                  label: 'Confirm Cancellation',
                  color: AppColors.dangerRed,
                  onPressed: () {
                    final ticketsSold = event.ticketsSold;
                    EventRepository.instance.cancelEvent(eventId);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrganizerEventCancelledScreen(
                          eventId: event.id,
                          totalRefunds: '$ticketsSold Ticket${ticketsSold == 1 ? '' : 's'}',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlineButtonWidget(
                  label: 'Keep Event',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyGray),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.label,
          ),
        ),
      ],
    );
  }
}
