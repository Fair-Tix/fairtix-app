import 'package:flutter/material.dart';

/// A ticket tier as shown to eventgoers, backed by `public.ticket_tiers`
/// (see supabase/schema.sql).
class TicketTier {
  const TicketTier({
    required this.id,
    required this.name,
    required this.seatingLabel,
    required this.price,
    this.remainingQuantity,
  });

  /// `ticket_tiers.tier_id` — needed so checkout can reference the exact
  /// tier row being purchased.
  final String id;
  final String name;
  final String seatingLabel; // e.g. "Reserved Seating", "Free Seating"
  final double price;

  /// `ticket_tiers.remaining_quantity`. Null when unknown (treated as
  /// available) — always populated once loaded via [PublicEventRepository].
  final int? remainingQuantity;

  bool get isSoldOut => remainingQuantity != null && remainingQuantity! <= 0;
}

/// Placeholder event model for UI scaffolding.
/// TODO: replace with the real model once Cloud Firestore's `events`
/// and `ticket_tiers` collections are wired up.
class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.venue,
    required this.dateLabel,
    required this.eventDateTime,
    required this.priceLabel,
    required this.accentColor,
    this.subtitle,
    this.description,
    this.tiers = const [],
  });

  /// Stable identifier for this event — mirrors EVENTS.event_id in the
  /// data dictionary. Used to check the one-ticket-per-account purchase
  /// limit and resale-listing eligibility per event, since UI equality
  /// can't safely rely on title text alone.
  final String id;
  final String title;
  final String venue;
  final String dateLabel;

  /// Structured start date/time for this event, used to compute the
  /// resale-listing closing window (24 hours before the event starts,
  /// per the study's resale rules). [dateLabel] remains the display
  /// string shown in the UI.
  final DateTime eventDateTime;
  final String priceLabel;
  final Color accentColor;
  final String? subtitle;
  final String? description;
  final List<TicketTier> tiers;

  /// Resale listings for this event automatically close 24 hours before
  /// it starts (system-enforced, per the study's resale rules).
  DateTime get resaleListingCloseTime => eventDateTime.subtract(const Duration(hours: 24));

  /// True once the resale window for this event has closed — no new
  /// resale listings can be created, and any still-active listings would
  /// already have been returned to their original owners.
  bool get isResaleWindowClosed => DateTime.now().isAfter(resaleListingCloseTime);

  /// "From ₱X" label for event lists (Dashboard, All Events), computed
  /// from the cheapest tier with the platform fee already folded in —
  /// this is the actual lowest price a buyer would pay, so it always
  /// matches what they see once they open the event and reach checkout.
  /// Falls back to the raw [priceLabel] field if no tiers are set.
  String get startingPriceLabel {
    if (tiers.isEmpty) return priceLabel;
    final lowestTierPrice = tiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    return 'From ${formatPeso(withPlatformFee(lowestTierPrice, kPrimaryPlatformFeeRate))}';
  }
}

/// Formats a peso amount like "₱5,000.00" without pulling in the intl package.
String formatPeso(double amount) {
  final wholePart = amount.truncate();
  final decimalPart = ((amount - wholePart) * 100).round().toString().padLeft(2, '0');
  final digits = wholePart.toString().split('').reversed.toList();
  final grouped = <String>[];
  for (int i = 0; i < digits.length; i++) {
    if (i != 0 && i % 3 == 0) grouped.add(',');
    grouped.add(digits[i]);
  }
  final wholeFormatted = grouped.reversed.join();
  return '₱$wholeFormatted.$decimalPart';
}

// FairTix's platform-fee rates. The fee is a backend split between the
// event organizer and FairTix (admin) — the buyer never sees it broken
// out anywhere in the app. Every buyer-facing price (tier list, resale
// market, checkout, receipt) already has the fee folded in via
// [withPlatformFee], so the number the user sees is the same number
// they pay, everywhere, with no separate "platform fee" line.
const double kPrimaryPlatformFeeRate = 0.10; // primary ticket purchases
const double kResalePlatformFeeRate = 0.05; // resale purchases (flat, per the study)

/// Adds the platform fee on top of a base (organizer/seller) price to get
/// the fee-inclusive total the buyer sees and pays.
double withPlatformFee(double basePrice, double rate) => basePrice + basePrice * rate;
