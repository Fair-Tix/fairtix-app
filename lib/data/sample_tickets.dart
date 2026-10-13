import '../models/ticket.dart';
import '../services/ticket_repository.dart';

/// Deprecated: kept only so any not-yet-migrated screens that still
/// import this list don't break. Real ticket data now comes from
/// [TicketRepository] (see my_tickets_screen.dart), which is refreshed
/// after every purchase and whenever My Tickets / an event's details
/// screen is opened.
final List<Ticket> sampleMyTickets = [];

/// True if the current user currently owns a valid or listed ticket for
/// [eventId] — i.e. they've already used their one-ticket-per-account
/// purchase slot for this event and haven't resold it (yet).
bool userOwnsTicketForEvent(String eventId) {
  return TicketRepository.instance.tickets.any(
    (t) => t.event.id == eventId && (t.status == TicketStatus.valid || t.status == TicketStatus.listed),
  );
}

/// True if the user is blocked from purchasing (primary or resale) a ticket
/// for [eventId] under FairTix's one-ticket-per-account-per-event purchase
/// limit because they still hold a ticket for it.
///
/// This is only the app-side shortcut that greys out the buy buttons. The
/// real rule lives on the server (checkout_quote, _do_ticket_purchase and
/// buy_resale_listing, via ticket_slot_used in supabase/checkout_guard.sql),
/// and it also covers the case this can't see: a user who already RESOLD
/// their ticket for the event doesn't get the slot back. They can still tap
/// Buy, and the server answers with a plain-sentence refusal.
bool isPurchaseLimitReached(String eventId) => userOwnsTicketForEvent(eventId);
