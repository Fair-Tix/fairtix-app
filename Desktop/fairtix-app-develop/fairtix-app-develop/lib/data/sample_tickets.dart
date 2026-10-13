import '../models/ticket.dart';
import '../services/ticket_repository.dart';

/// Deprecated: kept only so any not-yet-migrated screens that still
/// import this list don't break. Real ticket data now comes from
/// [TicketRepository] (see my_tickets_screen.dart), which is refreshed
/// after every purchase and whenever My Tickets / an event's details
/// screen is opened.
final List<Ticket> sampleMyTickets = [];

/// Event ids for which the current user has already resold their ticket.
/// Per the study's purchase-limit rule, once a user resells their ticket
/// for an event, that "slot" is not returned — they may not purchase
/// another ticket for the same event. Populated when a "your ticket has
/// been bought" notification is opened (see NotificationsScreen), which
/// simulates the resale completing and the ticket leaving `sampleMyTickets`.
/// TODO(backend): replace with a real query against TRANSACTIONS
/// (transaction_type == resale, seller_id == current user) once the
/// backend is wired up.
final Set<String> soldTicketEventIds = {};

/// True if the current user currently owns a valid or listed ticket for
/// [eventId] — i.e. they've already used their one-ticket-per-account
/// purchase slot for this event and haven't resold it (yet).
bool userOwnsTicketForEvent(String eventId) {
  return TicketRepository.instance.tickets.any(
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
