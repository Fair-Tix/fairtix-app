import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ticket.dart';
import '../theme/fairtix_palette.dart';
import 'ft_dark_ui.dart';
import 'ft_resale_ui.dart' show formatClosesAt;
import 'ft_transaction_ui.dart' show formatPesoShort;

/// Card for a listing in the "Market Listings" section of the Resale
/// Market — another user's ticket that's available to buy. Draws with the
/// surrounding [FtAuthTheme].
class MarketListingCard extends StatelessWidget {
  const MarketListingCard({super.key, required this.listing, required this.onBuyNow, this.isBlocked = false});

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
    final accent = listing.event.accentColor;
    final hsl = HSLColor.fromColor(accent);
    final deeper = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceFill,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, deeper],
              ),
            ),
            child: const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: t.titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: t.secondaryText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        listing.event.dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: t.subtitleColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: FairTixPalette.buttonGradient,
                      ),
                      child: Text(
                        listing.tier.name.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.verified_rounded, size: 18, color: t.success),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Listing closes ${formatClosesAt(closesAt)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: t.subtitleColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RESALE PRICE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: t.subtitleColor,
                ),
              ),
              const SizedBox(height: 2),
              if (isDiscounted)
                Text(
                  formatPesoShort(originalPrice),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: t.subtitleColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                formatPesoShort(resalePrice),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: t.activeAccent,
                ),
              ),
              const SizedBox(height: 10),
              Semantics(
                button: true,
                enabled: !isBlocked,
                label: isBlocked ? 'Limit reached' : 'Buy now',
                excludeSemantics: true,
                child: Opacity(
                  opacity: isBlocked ? 0.5 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: isBlocked ? null : FairTixPalette.buttonGradient,
                      color: isBlocked ? t.progressTrack : null,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: isBlocked ? null : onBuyNow,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          child: Text(
                            isBlocked ? 'Limit reached' : 'Buy now',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
