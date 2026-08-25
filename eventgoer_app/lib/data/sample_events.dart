import 'package:flutter/material.dart';

import '../models/event.dart';

/// Shared placeholder event catalogue for UI scaffolding.
/// TODO: replace with real data from Cloud Firestore's `events` and
/// `ticket_tiers` collections.
final List<EventSummary> sampleEvents = [
  EventSummary(
    id: 'evt_a1_love_ph_2026',
    title: 'A1 – Love in the Philippines Tour 2026',
    venue: 'Waterfront Cebu City Hotel & Casino',
    dateLabel: 'Friday, October 16, 2026 • 8:00 PM',
    eventDateTime: DateTime(2026, 10, 16, 20, 0),
    priceLabel: 'From ₱1,000',
    accentColor: Color(0xFF2B1B4A),
    description:
        'Experience A1 live — Mark Read, Ben Adams, Christian Ingebrigtsen, and Paul Marazzi — performing '
        'their greatest hits. Organized by Concert Republic. Tickets available via SM Tickets.',
    tiers: [
      TicketTier(name: 'VIP', seatingLabel: 'Reserved Seating', price: 5000),
      TicketTier(name: 'Gold', seatingLabel: 'Reserved Seating', price: 4000),
      TicketTier(name: 'Silver', seatingLabel: 'Reserved Seating', price: 3000),
      TicketTier(name: 'Bronze', seatingLabel: 'Free Seating', price: 2000),
      TicketTier(name: 'Balcony', seatingLabel: 'Free Seating', price: 1000),
    ],
  ),
  EventSummary(
    id: 'evt_bini_signals_tour',
    title: 'BINI Signals World Tour',
    venue: 'SM Seaside Cebu Arena',
    dateLabel: 'Sat, Nov 14 • 8 PM',
    eventDateTime: DateTime(2026, 11, 14, 20, 0),
    priceLabel: 'From ₱1,399',
    accentColor: Color(0xFF3A2159),
    description: 'BINI brings their Signals World Tour to Cebu with a full night of live performances.',
    tiers: [
      TicketTier(name: 'VIP', seatingLabel: 'Reserved Seating', price: 4500),
      TicketTier(name: 'General Admission', seatingLabel: 'Free Seating', price: 1399),
    ],
  ),
  EventSummary(
    id: 'evt_ivos_tour',
    title: 'IV OF SPADES Tour',
    venue: 'SM Seaside Cebu Arena',
    dateLabel: 'Sat, Dec 5 • 7 PM',
    eventDateTime: DateTime(2026, 12, 5, 19, 0),
    priceLabel: 'From ₱1,200',
    accentColor: Color(0xFF4B2E7A),
    description: 'IV of Spades performs a special one-night show at SM Seaside Cebu Arena.',
    tiers: [
      TicketTier(name: 'General Admission', seatingLabel: 'Free Seating', price: 1200),
    ],
  ),
  EventSummary(
    id: 'evt_lany_soft_world_tour',
    title: 'LANY: soft world tour',
    venue: 'SM Seaside Cebu Arena',
    dateLabel: 'Nov 6, 2026',
    eventDateTime: DateTime(2026, 11, 6, 20, 0),
    priceLabel: 'From ₱2,500',
    accentColor: Color(0xFF6A28E0),
    description: 'LANY brings the soft world tour to the Philippines for one night only.',
    tiers: [
      TicketTier(name: 'VIP', seatingLabel: 'Reserved Seating', price: 5500),
      TicketTier(name: 'General Admission', seatingLabel: 'Free Seating', price: 2500),
    ],
  ),
];
