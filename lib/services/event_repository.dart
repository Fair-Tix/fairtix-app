import '../models/organizer_event.dart';

/// In-memory store of the signed-in organizer's events.
///
/// TODO(backend): Replace the storage in this class with Postgres
/// reads/writes (the `events` / `ticket_tiers` tables — see
/// supabase/schema.sql) scoped to the signed-in organizer's `organizer_id`
/// (see Chapter III Data Dictionary: Events / Ticket Tiers). Screens only
/// call the public methods below (`events`, `addEvent`, `updateEvent`,
/// `cancelEvent`, `deleteEvent`, `getById`), so swapping the storage layer
/// should not require any UI changes. See docs/FairTix-Backend-Roadmap.md,
/// Phase 2.
///
/// Starts empty on every app run - no sample/dummy events are seeded here.
class EventRepository {
  EventRepository._();
  static final EventRepository instance = EventRepository._();

  final List<OrganizerEvent> _events = [];
  int _idCounter = 0;

  /// Read-only snapshot of the organizer's events.
  List<OrganizerEvent> get events => List.unmodifiable(_events);

  int get totalTicketsSold =>
      _events.fold(0, (sum, e) => sum + e.ticketsSold);

  double get totalGrossRevenue =>
      _events.fold(0.0, (sum, e) => sum + e.grossRevenue);

  OrganizerEvent? getById(String id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  OrganizerEvent addEvent({
    required String name,
    required String date,
    required String venue,
    String description = '',
    EventStatus status = EventStatus.published,
    List<TicketTier> tiers = const [],
  }) {
    final event = OrganizerEvent(
      id: _generateId(),
      name: name,
      date: date,
      venue: venue,
      description: description,
      status: status,
      tiers: tiers,
    );
    _events.add(event);
    return event;
  }

  void updateEvent(OrganizerEvent updated) {
    final index = _events.indexWhere((e) => e.id == updated.id);
    if (index != -1) {
      _events[index] = updated;
    }
  }

  void cancelEvent(String id) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index != -1) {
      _events[index] = _events[index].copyWith(status: EventStatus.cancelled);
    }
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
  }

  String _generateId() {
    _idCounter += 1;
    return 'FT-${DateTime.now().millisecondsSinceEpoch}-$_idCounter';
  }
}
