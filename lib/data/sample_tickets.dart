import '../models/event.dart';
import '../models/ticket.dart';
import 'sample_events.dart';

/// Placeholder "tickets the current user owns" for UI scaffolding.
/// TODO: replace with a real query against the TICKETS Firestore
/// collection filtered by owner_id == current user once wired up.
final List<Ticket> sampleMyTickets = [
  Ticket(
    id: 'tkt_0001',
    event: sampleEvents[0], // A1 – Love in the Philippines Tour 2026
    tier: sampleEvents[0].tiers[0], // VIP
    ownerName: 'Heron Dave Mahilum',
    qrToken: 'FTX-A1-VIP-0001-8F3D',
    status: TicketStatus.listed,
    resalePrice: 5000,
  ),
  Ticket(
    id: 'tkt_0002',
    event: sampleEvents[0], // A1 – Love in the Philippines Tour 2026
    tier: const TicketTier(name: 'General Access', seatingLabel: 'Free Seating', price: 1000),
    ownerName: 'Heron Dave Mahilum',
    qrToken: 'FTX-A1-GA-0002-2C7B',
  ),
  Ticket(
    id: 'tkt_0003',
    event: sampleEvents[1], // BINI Signals World Tour
    tier: sampleEvents[1].tiers[1], // General Admission
    ownerName: 'Heron Dave Mahilum',
    qrToken: 'FTX-BINI-GA-0003-5A19',
  ),
];

/// Event ids for which the current user has already resold their ticket.
/// Per the study's purchase-limit rule, once a user resells their ticket
/// for an event, that "slot" is not returned — they may not purchase
/// another ticket for the same event. Populated when a "your ticket has
/// been bought" notification is opened (see NotificationsScreen), which
/// simulates the resale completing and the ticket leaving `sampleMyTickets`.
/// TODO: replace with a real query against TRANSACTIONS (transaction_type
/// == resale, seller_id == current user) once the backend is wired up.
final Set<String> soldTicketEventIds = {};

/// True if the current user currently owns a valid or listed ticket for
/// [eventId] — i.e. they've already used their one-ticket-per-account
/// purchase slot for this event and haven't resold it (yet).
bool userOwnsTicketForEvent(String eventId) {
  return sampleMyTickets.any(
    (t) => t.event.id == eventId && (t.status == TicketStatus.valid || t.status == TicketStatus.listed),
  );
}

/// True if the current user has already resold a ticket for [eventId].
bool userHasResoldTicketForEvent(String eventId) => soldTicketEventIds.contains(eventId);

/// True if the user is blocked from purchasing (primary or resale) a
/// ticket for [eventId] under FairTix's one-ticket-per-account-per-event
/// purchase limit — either because they still hold a ticket for it, or
/// because they've already resold one and the slot isn't returned.
bool isPurchaseLimitReached(String eventId) =>
    userOwnsTicketForEvent(eventId) || userHasResoldTicketForEvent(eventId);
