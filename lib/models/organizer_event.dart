/// Lifecycle status of an organizer's event.
enum EventStatus {
  draft,
  published,
  cancelled,
  completed;

  String get label {
    switch (this) {
      case EventStatus.draft:
        return 'Draft';
      case EventStatus.published:
        return 'Published';
      case EventStatus.cancelled:
        return 'Cancelled';
      case EventStatus.completed:
        return 'Completed';
    }
  }
}

/// A single ticket tier belonging to an [OrganizerEvent].
class TicketTier {
  final String name;
  final double price;
  final int quantity;

  /// Tickets sold so far in this tier. Starts at 0 for every newly created
  /// tier - real sales counts will come from the Tickets collection once
  /// the buyer-facing app and backend are connected.
  final int sold;

  const TicketTier({
    required this.name,
    required this.price,
    required this.quantity,
    this.sold = 0,
  });

  double get grossRevenue => price * sold;

  TicketTier copyWith({
    String? name,
    double? price,
    int? quantity,
    int? sold,
  }) {
    return TicketTier(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sold: sold ?? this.sold,
    );
  }
}

/// A single organizer-owned event.
///
/// TODO(backend): This currently lives only in memory via
/// [EventRepository]. Once Postgres is wired in, this model should mirror
/// the `events` / `ticket_tiers` tables (see Chapter III Data Dictionary
/// and supabase/schema.sql) and be read/written through Supabase instead
/// of the in-memory list. Screens depend only on this model and on
/// `EventRepository`'s method signatures, so that swap should not require
/// UI changes. See docs/FairTix-Backend-Roadmap.md, Phase 2.
class OrganizerEvent {
  final String id;
  final String name;
  final String date;
  final String venue;
  final String description;
  final EventStatus status;
  final List<TicketTier> tiers;

  const OrganizerEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.venue,
    this.description = '',
    this.status = EventStatus.published,
    this.tiers = const [],
  });

  int get ticketsSold => tiers.fold(0, (sum, t) => sum + t.sold);
  int get ticketsTotal => tiers.fold(0, (sum, t) => sum + t.quantity);
  double get grossRevenue =>
      tiers.fold(0.0, (sum, t) => sum + t.grossRevenue);
  String get soldLabel => '$ticketsSold / $ticketsTotal';

  OrganizerEvent copyWith({
    String? name,
    String? date,
    String? venue,
    String? description,
    EventStatus? status,
    List<TicketTier>? tiers,
  }) {
    return OrganizerEvent(
      id: id,
      name: name ?? this.name,
      date: date ?? this.date,
      venue: venue ?? this.venue,
      description: description ?? this.description,
      status: status ?? this.status,
      tiers: tiers ?? this.tiers,
    );
  }
}
