import '../models/ticket.dart';

/// Other users' active resale listings, browsed from the Resale Market.
/// TODO(backend): replace with a real query against RESALE_LISTINGS
/// (status == active) joined with TICKETS, excluding the current user's
/// own listings, once the resale backend is wired up.
///
/// Starts empty on every app run — no sample/dummy listings are seeded
/// here. Screens that read this already render an empty state when the
/// list has no entries.
final List<Ticket> sampleResaleListings = [];
