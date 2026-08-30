import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../navigation/app_nav.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pill_button.dart';

/// Shown after a ticket is successfully listed for resale — confirms the
/// listing price and lets the seller know when the listing will
/// automatically close if it doesn't sell.
class ResaleConfirmationScreen extends StatelessWidget {
  const ResaleConfirmationScreen({super.key, required this.ticket});

  final Ticket ticket;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _formatCloseDateTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_months[dt.month - 1]} ${dt.day}, $hour12:$minute $period';
  }

  void _handleViewListing(BuildContext context) {
    // Jumps to the Resale Market tab within the persistent bottom-nav
    // shell, where the newly created listing now appears alongside
    // other active resale listings.
    navigateToTab(context, 2);
  }

  void _handleBackToTickets(BuildContext context) {
    navigateToTab(context, 1);
  }

  @override
  Widget build(BuildContext context) {
    final event = ticket.event;
    final price = ticket.resalePrice ?? ticket.tier.price;

    return Scaffold(
      body: GradientBackground(
        gradient: AppGradients.confirmation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: AppColors.white.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.done_all_rounded, color: AppColors.accentPurple, size: 40),
              ),
              const SizedBox(height: 26),
              const Text('Ticket Listed for Resale!', style: AppTextStyles.heading, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text(
                'Your ticket is now visible to verified buyers',
                textAlign: TextAlign.center,
                style: AppTextStyles.tagline,
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ticket.tier.name.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accentPurple),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('RESALE PRICE', style: AppTextStyles.cardLabel),
                    const SizedBox(height: 4),
                    Text(
                      formatPeso(price),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.accentPurple),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18, color: AppColors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This listing closes automatically on ${_formatCloseDateTime(event.resaleListingCloseTime)} — 24 hours before the event. If it hasn\u2019t sold by then, the ticket returns to you.',
                        style: AppTextStyles.tagline.copyWith(fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              PillButton(
                label: 'View Listing',
                onPressed: () => _handleViewListing(context),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => _handleBackToTickets(context),
                child: const Text(
                  'Back to My Tickets',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
