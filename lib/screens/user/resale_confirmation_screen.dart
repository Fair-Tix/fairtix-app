import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../navigation/app_nav.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_resale_ui.dart';
import '../../widgets/ft_transaction_ui.dart' show formatPesoShort;

/// Shown after a ticket is successfully listed for resale — confirms the
/// listing price, what the seller will receive, and when the listing will
/// automatically close if it doesn't sell.
class ResaleConfirmationScreen extends StatelessWidget {
  const ResaleConfirmationScreen({super.key, required this.ticket});

  final Ticket ticket;

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
    final t = FtAuthTheme.live(context);
    final event = ticket.event;
    final price = ticket.resalePrice ?? ticket.tier.price;
    final fee = (price * kResaleSellerFeeRate * 100).round() / 100;

    return FtResultScaffold(
      icon: Icons.sell_outlined,
      title: 'Your ticket is listed',
      subtitle: 'The listing closes automatically 24 hours before the event.',
      primaryLabel: 'View My Listings',
      onPrimary: () => _handleViewListing(context),
      secondaryLabel: 'Back to My Tickets',
      onSecondary: () => _handleBackToTickets(context),
      body: [
        FtSurfaceCard(
          radius: 26,
          child: Column(
            children: [
              FtSummaryRow(label: 'Event', value: '${event.title} · ${ticket.tier.name}'),
              const SizedBox(height: 14),
              FtSummaryRow(label: 'Asking price', value: formatPesoShort(price)),
              const SizedBox(height: 14),
              FtSummaryRow(label: 'Closes', value: formatClosesAt(event.resaleListingCloseTime)),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: t.divider),
              const SizedBox(height: 16),
              FtSummaryRow(
                label: 'You’ll receive',
                value: formatPesoShort(price - fee),
                valueColor: t.success,
                strong: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FtNote(
          icon: Icons.verified_user_outlined,
          text: 'Paid out after the buyer’s new QR is issued.',
        ),
      ],
    );
  }
}
