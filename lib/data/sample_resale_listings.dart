import '../models/event.dart';
import '../models/ticket.dart';
import 'sample_events.dart';

/// Placeholder "other users' active resale listings" for UI scaffolding.
/// TODO: replace with a real query against RESALE_LISTINGS (status ==
/// active) joined with TICKETS, excluding the current user's own
/// listings, once the resale backend is wired up.
final List<Ticket> sampleResaleListings = [
  Ticket(
    id: 'rsl_1001',
    event: sampleEvents[1], // BINI Signals World Tour
    tier: const TicketTier(name: 'VIP', seatingLabel: 'Reserved Seating', price: 1399),
    ownerName: 'Juan Dela Cruz',
    qrToken: 'FTX-BINI-VIP-1001-RS01',
    status: TicketStatus.listed,
    resalePrice: 1399,
  ),
  Ticket(
    id: 'rsl_1002',
    event: sampleEvents[2], // IV OF SPADES Tour
    tier: const TicketTier(name: 'Box Regular B', seatingLabel: 'Reserved Seating', price: 1500),
    ownerName: 'Maria Santos',
    qrToken: 'FTX-IVOS-BOXB-1002-RS02',
    status: TicketStatus.listed,
    resalePrice: 1500,
  ),
  Ticket(
    id: 'rsl_1003',
    event: sampleEvents[0], // A1 – Love in the Philippines Tour 2026
    tier: const TicketTier(name: 'VIP', seatingLabel: 'Reserved Seating', price: 5000),
    ownerName: 'Carlo Reyes',
    qrToken: 'FTX-A1-VIP-1003-RS03',
    status: TicketStatus.listed,
    resalePrice: 4500,
  ),
];
