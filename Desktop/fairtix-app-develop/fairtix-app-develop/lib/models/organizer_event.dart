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
  int get remaining => quantity - sold;

  TicketTier copyWith({String? name, double? price, int? quantity, int? sold}) {
    return TicketTier(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sold: sold ?? this.sold,
    );
  }
}

/// Whether an event is a single-day event or the multi-day *parent* of a
/// generated run of per-day child events (see [OrganizerEvent.parentEventId]
/// / [OrganizerEvent.dayNumber], and `EventRepository.createEvent`).
/// Mirrors `public.events.event_type` (schema.sql).
enum EventSpan { singleDay, multiDay }

/// A single organizer-owned event.
///
/// Backed by `public.events` / `public.ticket_tiers` via [EventRepository]
/// (see Chapter III Data Dictionary and supabase/schema.sql). Screens
/// depend only on this model and on `EventRepository`'s method signatures.
class OrganizerEvent {
  final String id;
  final String name;
  final String date;
  final String venue;
  final String description;
  final EventStatus status;
  final List<TicketTier> tiers;

  /// Single-day event, or the multi-day parent/child span this row
  /// belongs to. A multi-day *parent* row (see [parentEventId] == null with
  /// [span] == multiDay) is a container only — [EventRepository.events]
  /// filters child day-rows out of the top-level list so My Events / the
  /// dashboard show one line per event series, matching how organizers
  /// think about "my BINI World Tour", not "my BINI World Tour, Day 3".
  final EventSpan span;

  /// For a generated multi-day child row, the id of its parent `events`
  /// row (`public.events.parent_event_id`). Null for single-day events and
  /// for the parent row itself.
  final String? parentEventId;

  /// For a generated multi-day child row, its 1-based day number within
  /// the run (`public.events.day_number`). Null otherwise.
  final int? dayNumber;

  /// Public URL/path of the event's banner image in the `event_banners`
  /// Storage bucket (`public.events.banner_image_url`). Null until the
  /// organizer uploads one via `EventRepository.uploadEventBanner`.
  final String? bannerUrl;

  /// Paths of supporting documents (venue contract, LGU permit, etc.) in
  /// the private `event_documents` Storage bucket
  /// (`public.events.supporting_document_urls`).
  final List<String> supportingDocumentUrls;

  /// For a multi-day parent: how many live (non-canceled) days it has, so
  /// roll-up tier figures can be shown per day. 0 for single-day events.
  final int dayCount;

  const OrganizerEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.venue,
    this.description = '',
    this.status = EventStatus.published,
    this.tiers = const [],
    this.span = EventSpan.singleDay,
    this.parentEventId,
    this.dayNumber,
    this.bannerUrl,
    this.supportingDocumentUrls = const [],
    this.dayCount = 0,
  });

  int get ticketsSold => tiers.fold(0, (sum, t) => sum + t.sold);
  int get ticketsTotal => tiers.fold(0, (sum, t) => sum + t.quantity);
  double get grossRevenue => tiers.fold(0.0, (sum, t) => sum + t.grossRevenue);
  int get ticketsRemaining => ticketsTotal - ticketsSold;
  String get soldLabel => '$ticketsSold / $ticketsTotal';
  bool get isMultiDay => span == EventSpan.multiDay;

  static String formatDateRange(
    String startDate,
    String endDate,
    bool isMultiDay,
  ) {
    final start = _parseDate(startDate);
    if (!isMultiDay) return _formatDate(start);

    final end = _parseDate(endDate);
    if (end.isBefore(start)) {
      throw FormatException('End date must not be before start date.');
    }
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return _formatDate(start);
    }
    if (start.year == end.year && start.month == end.month) {
      return '${_monthNames[start.month - 1]} ${start.day}-${end.day}, '
          '${start.year}';
    }
    if (start.year == end.year) {
      return '${_formatMonthDay(start)}-${_formatMonthDay(end)}, ${end.year}';
    }
    return '${_formatDate(start)}-${_formatDate(end)}';
  }

  static DateTime _parseDate(String value) {
    final input = value.trim();
    final isoDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$')
        .firstMatch(input);
    final usDate = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$')
        .firstMatch(input);

    final year = isoDate != null
        ? int.parse(isoDate.group(1)!)
        : usDate != null
            ? int.parse(usDate.group(3)!)
            : null;
    final month = isoDate != null
        ? int.parse(isoDate.group(2)!)
        : usDate != null
            ? int.parse(usDate.group(1)!)
            : null;
    final day = isoDate != null
        ? int.parse(isoDate.group(3)!)
        : usDate != null
            ? int.parse(usDate.group(2)!)
            : null;
    if (year == null || month == null || day == null) {
      throw FormatException('Invalid event date: $value');
    }

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw FormatException('Invalid event date: $value');
    }
    return parsed;
  }

  static String _formatDate(DateTime date) {
    return '${_formatMonthDay(date)}, ${date.year}';
  }

  static String _formatMonthDay(DateTime date) {
    return '${_monthNames[date.month - 1]} ${date.day}';
  }

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  OrganizerEvent copyWith({
    String? name,
    String? date,
    String? venue,
    String? description,
    EventStatus? status,
    List<TicketTier>? tiers,
    String? bannerUrl,
    List<String>? supportingDocumentUrls,
    int? dayCount,
  }) {
    return OrganizerEvent(
      id: id,
      name: name ?? this.name,
      date: date ?? this.date,
      venue: venue ?? this.venue,
      description: description ?? this.description,
      status: status ?? this.status,
      tiers: tiers ?? this.tiers,
      span: span,
      parentEventId: parentEventId,
      dayNumber: dayNumber,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      supportingDocumentUrls:
          supportingDocumentUrls ?? this.supportingDocumentUrls,
      dayCount: dayCount ?? this.dayCount,
    );
  }
}
