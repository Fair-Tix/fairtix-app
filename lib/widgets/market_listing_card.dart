import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ticket.dart';
import 'ft_dark_ui.dart';
import 'ft_resale_ui.dart' show formatClosesAt;
import 'ft_ticket_card.dart';
import 'ft_transaction_ui.dart' show formatPesoShort;

/// Card for a listing in the "Market Listings" section of the Resale
/// Market: another user's ticket that's available to buy. Uses the same
/// poster ticket card as My Tickets ([FtTicketCard]) and draws with the
/// surrounding [FtAuthTheme]. Spacing between cards is up to the caller.
class MarketListingCard extends StatelessWidget {
  const MarketListingCard({
    super.key,
    required this.listing,
    required this.onBuyNow,
    this.isBlocked = false,
  });

  final Ticket listing;
  final VoidCallback onBuyNow;

  /// True when FairTix's one-ticket-per-account-per-event purchase limit
  /// blocks the current user from buying this listing (they already hold
  /// or have already resold a ticket for this event). The card stays
  /// visible but the buy action is disabled with an explanatory label.
  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    // The buyer pays exactly the listing price. The struck-through number is
    // what the original owner paid, so a discounted listing reads as a deal.
    final resalePrice = listing.resalePrice ?? listing.tier.price;
    final originalPrice = listing.originalPrice;
    final isDiscounted = resalePrice < originalPrice;
    final closesAt = listing.event.resaleListingCloseTime;

    return FtTicketCard(
      event: listing.event,
      tierName: listing.tier.name,
      seatingLabel: listing.tier.seatingLabel,
      chipLabel: 'Resale',
      chipColor: t.activeAccent,
      semanticLabel: '${listing.event.title}, ${listing.tier.name}, '
          '${listing.event.dateLabel}, resale price ${formatPesoShort(resalePrice)}',
      footer: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatPesoShort(resalePrice),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: t.activeAccent,
                ),
              ),
              if (isDiscounted) ...[
                const SizedBox(width: 6),
                Text(
                  formatPesoShort(originalPrice),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.2,
                    color: t.subtitleColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Closes ${formatClosesAt(closesAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.2, color: t.subtitleColor),
          ),
        ],
      ),
      action: FtTicketButton(
        label: isBlocked ? 'Limit reached' : 'Buy now',
        enabled: !isBlocked,
        onTap: onBuyNow,
      ),
      actionIsInteractive: true,
    );
  }
}
