import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'organizer-scaffold.dart';
import 'organizer-my-events.dart';

class OrganizerEventEditedScreen extends StatelessWidget {
  final String eventName;

  const OrganizerEventEditedScreen({super.key, required this.eventName});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeLabel = 'Today, ${_formatTime(now)}';

    return OrganizerScaffold(
      pageTitle: 'Event Updated',
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
                    color: AppColors.successGreenBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_circle_outline,
                      color: AppColors.successGreen, size: 32),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Event Updated!',
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Changes have been saved and the public event page has '
                  'been updated.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyGray.copyWith(height: 1.5),
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
                      _infoRow('Event', eventName),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: AppColors.borderLight),
                      ),
                      _infoRow('Last Updated', timeLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                PrimaryButton(
                  label: 'View Event',
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
                  label: 'Back to My Events',
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrganizerMyEventsScreen(),
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}