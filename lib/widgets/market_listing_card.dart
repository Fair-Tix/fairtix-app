import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/ticket.dart';
import '../theme/app_theme.dart';

/// Card for a listing in the "Market Listings" section of the Resale
/// Market — another user's ticket that's available to buy.
class MarketListingCard extends StatelessWidget {
  const MarketListingCard({super.key, required this.listing, required this.onBuyNow, this.isBlocked = false});

  final Ticket listing;
  final VoidCallback onBuyNow;

  /// True when FairTix's one-ticket-per-account-per-event purchase limit
  /// blocks the current user from buying this listing (they already hold
  /// or have already resold a ticket for this event). The card stays
  /// visible but the buy action is disabled with an explanatory label.
  final bool isBlocked;

  static const _closesFormat = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _formatCloseDate(DateTime dt) {
    final month = _closesFormat[dt.month - 1];
    return '$month ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final resalePrice = listing.resalePrice ?? listing.tier.price;
    final buyerResalePrice = withPlatformFee(resalePrice, kResalePlatformFeeRate);
    final buyerOriginalPrice = withPlatformFee(listing.tier.price, kPrimaryPlatformFeeRate);
    final bool isDiscounted = buyerResalePrice < buyerOriginalPrice;
    final closesAt = listing.event.resaleListingCloseTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: listing.event.accentColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.music_note_rounded, color: AppColors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        listing.event.dateLabel.split(' \u2022 ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMuted.copyWith(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        listing.tier.name,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Listing closes ${_formatCloseDate(closesAt)}',
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('RESALE PRICE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.3)),
              const SizedBox(height: 2),
              if (isDiscounted)
                Text(
                  formatPeso(buyerOriginalPrice).replaceAll('.00', ''),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                formatPeso(buyerResalePrice).replaceAll('.00', ''),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.accentPurple),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: isBlocked ? null : onBuyNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked ? AppColors.textMuted.withValues(alpha: 0.3) : AppColors.accentPurple,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    isBlocked ? 'Limit Reached' : 'Buy Now',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
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
