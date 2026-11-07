import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ticket.dart';
import '../theme/fairtix_palette.dart';
import 'ft_dark_ui.dart';
import 'ft_resale_ui.dart' show formatClosesAt;
import 'ft_ticket_card.dart';
import 'ft_transaction_ui.dart' show formatPesoShort;

/// Card for the "My Listed Tickets" section of the Resale Market: one of the
/// current user's own tickets that's currently listed for resale. Uses the
/// same poster ticket card as My Tickets ([FtTicketCard]); the footer shows
/// the listing price and, when [onCancel] is given, a "Cancel listing"
/// action. Spacing between cards is up to the caller.
class MyListingCard extends StatelessWidget {
  const MyListingCard({super.key, required this.ticket, required this.onTap, this.onCancel});

  final Ticket ticket;
  final VoidCallback onTap;

  /// Called when the seller taps "Cancel listing". Hidden when null.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final price = ticket.resalePrice ?? ticket.tier.price;
    final closesAt = ticket.event.resaleListingCloseTime;
    final isClosingSoon = closesAt.difference(DateTime.now()).inHours <= 24;
    final warning = FairTixPalette.of(context).warning;
    final statusColor = isClosingSoon ? warning : t.success;

    return FtTicketCard(
      event: ticket.event,
      tierName: ticket.tier.name,
      seatingLabel: ticket.tier.seatingLabel,
      chipLabel: isClosingSoon ? 'Closing soon' : 'Live',
      chipColor: statusColor,
      semanticLabel: '${ticket.event.title}, ${ticket.tier.name}, listed at '
          '${formatPesoShort(price)}, ${isClosingSoon ? 'closing soon' : 'live'}. View details',
      onTap: onTap,
      actionIsInteractive: onCancel != null,
      footer: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatPesoShort(price),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: t.activeAccent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Closes ${formatClosesAt(closesAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              height: 1.2,
              fontWeight: isClosingSoon ? FontWeight.w700 : FontWeight.w400,
              color: isClosingSoon ? warning : t.subtitleColor,
            ),
          ),
        ],
      ),
      action: onCancel == null
          ? const FtTicketButton(label: 'View details')
          : FtTicketButton(
              label: 'Cancel listing',
              outlined: true,
              color: t.danger,
              onTap: onCancel,
            ),
    );
  }
}
