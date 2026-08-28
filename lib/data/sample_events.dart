import '../models/event.dart';

/// Event catalogue shown to eventgoers.
/// TODO(backend): replace with a real query against Cloud Firestore's
/// `events` and `ticket_tiers` collections (status == published) once
/// the backend is wired up.
///
/// Starts empty on every app run — no sample/dummy events are seeded
/// here. Screens that read this already render an empty state when the
/// list has no entries.
final List<EventSummary> sampleEvents = [];
