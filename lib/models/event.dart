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
    this.bannerUrl,
    this.days = const [],
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

  /// Directly-loadable public URL of the event's banner image (the
  /// `event_banners` Storage bucket, via `public.events.banner_image_url`).
  /// Null when the organizer hasn't uploaded one — screens then fall back
  /// to the [accentColor] placeholder.
  final String? bannerUrl;

  /// For a multi-day event, one [EventSummary] per day, in day order — each
  /// is the generated child event (own id, date and ticket tiers, so
  /// tickets, sold-out counts and the one-ticket-per-day limit all work
  /// per day). Empty for single-day events.
  final List<EventSummary> days;

  /// True for a multi-day event whose per-day child events were loaded.
  bool get isMultiDay => days.isNotEmpty;

  /// Resale listings for this event automatically close 24 hours before
  /// it starts (system-enforced, per the study's resale rules).
  DateTime get resaleListingCloseTime => eventDateTime.subtract(const Duration(hours: 24));

  /// True once the resale window for this event has closed — no new
  /// resale listings can be created, and any still-active listings would
  /// already have been returned to their original owners.
  bool get isResaleWindowClosed => DateTime.now().isAfter(resaleListingCloseTime);

  /// "From ₱X" label for event lists (Dashboard, All Events), computed
  /// from the cheapest tier. The buyer pays exactly the listed tier price
  /// (FairTix's fee comes out of the organizer's proceeds), so this is the
  /// real lowest price and always matches what they see at checkout.
  /// Falls back to the raw [priceLabel] field if no tiers are set.
  String get startingPriceLabel {
    if (tiers.isEmpty) return priceLabel;
    final lowestTierPrice = tiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    if (lowestTierPrice <= 0) return 'Free';
    return 'From ${formatPeso(lowestTierPrice)}';
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

// FEE MODEL: the buyer pays exactly the listed price, with nothing added on
// top, so there is no buyer-side fee in the app at all. FairTix's fee comes
// out of the organizer's / seller's proceeds on the server: primary sales
// 8% / 9% / 10% by the organizer's plan (plan_fee_rate in
// supabase/purchase_functions.sql), resale a flat 5% deducted from the seller
// (buy_resale_listing in supabase/resale_purchase.sql).
//
// If a buyer-side surcharge were ever reintroduced, the server would have to
// charge it too: checkout_quote in supabase/checkout_guard.sql and
// _do_ticket_purchase in supabase/purchase_functions.sql.

/// Flat fee FairTix keeps from a resale, deducted from the SELLER's
/// proceeds (per the study); the resale buyer pays only the listing price.
/// Mirrors c_resale_fee_rate in supabase/resale_purchase.sql.
const double kResaleSellerFeeRate = 0.05;
