import 'package:supabase_flutter/supabase_flutter.dart';

import 'csv_export.dart';

/// Thrown when loading or changing resale listings / fraud alerts fails.
class AdminResaleException implements Exception {
  final String message;
  const AdminResaleException(this.message);
}

/// One resale listing as the admin sees it.
class ResaleListingEntry {
  const ResaleListingEntry({
    required this.id,
    required this.ticketId,
    required this.sellerId,
    required this.sellerName,
    required this.sellerEmail,
    required this.eventTitle,
    required this.tierName,
    required this.originalPrice,
    required this.listingPrice,
    required this.status,
    required this.listedAt,
    this.soldAt,
  });

  final String id;
  final String ticketId;
  final String sellerId;
  final String sellerName;
  final String sellerEmail;
  final String eventTitle;
  final String tierName;

  /// What the seller originally paid (`tickets.purchase_price`).
  final double originalPrice;
  final double listingPrice;

  /// Raw `resale_listings.listing_status`: active | sold | canceled | expired.
  final String status;
  final DateTime listedAt;
  final DateTime? soldAt;

  /// Listing price as a fraction of the original (0.5 to 1.0 is allowed by
  /// the server). There is no "markup": prices above the original are
  /// impossible, so the interesting number is how far below it is.
  double get fractionOfOriginal => originalPrice > 0 ? listingPrice / originalPrice : 0;

  /// Close to the 50% floor: the same rule the automatic price flag uses
  /// (60% or lower, see supabase/fraud_alerts.sql).
  bool get isNearFloor => originalPrice > 0 && fractionOfOriginal <= 0.60;

  bool get isActive => status == 'active';

  String get statusLabel => switch (status) {
    'active' => 'Active',
    'sold' => 'Sold',
    'canceled' => 'Canceled',
    'expired' => 'Expired',
    _ => status,
  };

  factory ResaleListingEntry.fromRow(Map<String, dynamic> row) {
    final seller = row['users'] as Map<String, dynamic>?;
    final ticket = row['tickets'] as Map<String, dynamic>?;
    final tier = ticket?['ticket_tiers'] as Map<String, dynamic>?;
    final event = tier?['events'] as Map<String, dynamic>?;
    final soldAt = row['sold_at'] as String?;
    return ResaleListingEntry(
      id: row['listing_id'] as String,
      ticketId: row['ticket_id'] as String,
      sellerId: row['seller_id'] as String,
      sellerName: (seller?['full_name'] as String?) ?? 'Unknown seller',
      sellerEmail: (seller?['email'] as String?) ?? '',
      eventTitle: (event?['title'] as String?) ?? 'Unknown event',
      tierName: (tier?['tier_name'] as String?) ?? 'Ticket',
      originalPrice: (ticket?['purchase_price'] as num?)?.toDouble() ?? 0,
      listingPrice: (row['listing_price'] as num).toDouble(),
      status: row['listing_status'] as String,
      listedAt: DateTime.parse(row['listed_at'] as String).toLocal(),
      soldAt: soldAt == null ? null : DateTime.parse(soldAt).toLocal(),
    );
  }
}

/// The resale activity report as CSV text (header row + one row per
/// listing). Used by both the Resale Monitoring export and the Resale
/// Activity report on Revenue & Reports, so the two always match.
String resaleListingsToCsv(List<ResaleListingEntry> rows) {
  return toSafeCsv(resaleListingsToRows(rows));
}

/// The same report as raw rows (first row = header), shared by the CSV and
/// PDF exports.
List<List<Object?>> resaleListingsToRows(List<ResaleListingEntry> rows) {
  return [
    [
      'Listing ID', 'Seller', 'Seller Email', 'Event', 'Tier', 'Original Price (PHP)',
      'Resale Price (PHP)', '% of Original', 'Status', 'Listed At', 'Sold At',
    ],
    for (final l in rows)
      [
        l.id,
        l.sellerName,
        l.sellerEmail,
        l.eventTitle,
        l.tierName,
        l.originalPrice.toStringAsFixed(2),
        l.listingPrice.toStringAsFixed(2),
        (l.fractionOfOriginal * 100).round(),
        l.statusLabel,
        l.listedAt.toIso8601String(),
        l.soldAt?.toIso8601String() ?? '',
      ],
  ];
}

/// One fraud alert / price flag (`public.fraud_alerts`).
class FraudAlertEntry {
  const FraudAlertEntry({
    required this.id,
    required this.type,
    required this.source,
    required this.severity,
    required this.status,
    required this.details,
    required this.createdAt,
    this.userId,
    this.userName,
    this.userEmail,
    this.eventTitle,
    this.listingId,
    this.ticketId,
    this.reviewedAt,
    this.resolutionNote,
  });

  final String id;

  /// near_floor_price | rapid_relist | organizer_report
  final String type;

  /// system | organizer
  final String source;

  /// low | medium | high
  final String severity;

  /// open | reviewing | resolved | dismissed
  final String status;
  final String details;
  final DateTime createdAt;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? eventTitle;
  final String? listingId;
  final String? ticketId;
  final DateTime? reviewedAt;
  final String? resolutionNote;

  /// Short, readable id for the table ("A1B2C3D4").
  String get shortId => id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  bool get isClosed => status == 'resolved' || status == 'dismissed';
  bool get isSystem => source == 'system';

  String get typeLabel => switch (type) {
    'near_floor_price' => 'Near-floor price',
    'rapid_relist' => 'Rapid relisting',
    'organizer_report' => 'Organizer report',
    _ => type,
  };

  String get sourceLabel => isSystem ? 'System' : 'Organizer';

  String get severityLabel => switch (severity) {
    'high' => 'High',
    'low' => 'Low',
    _ => 'Medium',
  };

  String get statusLabel => switch (status) {
    'open' => 'Open',
    'reviewing' => 'Reviewing',
    'resolved' => 'Resolved',
    'dismissed' => 'Dismissed',
    _ => status,
  };

  factory FraudAlertEntry.fromRow(Map<String, dynamic> row) {
    final user = row['users'] as Map<String, dynamic>?;
    final event = row['events'] as Map<String, dynamic>?;
    final reviewedAt = row['reviewed_at'] as String?;
    return FraudAlertEntry(
      id: row['alert_id'] as String,
      type: row['alert_type'] as String,
      source: row['source'] as String,
      severity: row['severity'] as String,
      status: row['status'] as String,
      details: row['details'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      userId: row['user_id'] as String?,
      userName: user?['full_name'] as String?,
      userEmail: user?['email'] as String?,
      eventTitle: event?['title'] as String?,
      listingId: row['listing_id'] as String?,
      ticketId: row['ticket_id'] as String?,
      reviewedAt: reviewedAt == null ? null : DateTime.parse(reviewedAt).toLocal(),
      resolutionNote: row['resolution_note'] as String?,
    );
  }
}

/// Admin side of the resale market: every listing, the automatic price-flag
/// / fraud alert queue, and the two actions an admin can take.
///
/// Reads work through RLS (everyone signed in can read listings; only admins
/// can read `fraud_alerts`). The two writes go through admin-only Postgres
/// functions in supabase/fraud_alerts.sql, so the app never edits these
/// tables directly.
class AdminResaleService {
  AdminResaleService._();
  static final AdminResaleService instance = AdminResaleService._();

  /// Newest first.
  Future<List<ResaleListingEntry>> fetchListings() async {
    // Close any listing that has passed its 24-hour cutoff first, so the
    // admin never sees (or tries to remove) a listing that should already be
    // expired. Housekeeping only: a failure here must not block the list.
    try {
      await Supabase.instance.client.rpc('expire_resale_listings');
    } catch (_) {
      // Ignored on purpose.
    }

    try {
      final rows = await Supabase.instance.client
          .from('resale_listings')
          .select('''
            listing_id, ticket_id, seller_id, listing_price, listing_status,
            listed_at, sold_at,
            users(full_name, email),
            tickets(purchase_price, ticket_tiers(tier_name, events(title)))
          ''')
          .order('listed_at', ascending: false) as List;
      return rows
          .map((r) => ResaleListingEntry.fromRow(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminResaleException('Could not load resale listings: ${e.message}');
    }
  }

  /// Takes an active listing off the market. The ticket goes back to valid
  /// and the seller gets an in-app notification (with [reason] if given).
  Future<void> removeListing(String listingId, {String? reason}) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_remove_resale_listing',
        params: {'p_listing_id': listingId, 'p_reason': reason},
      );
    } on PostgrestException catch (e) {
      throw AdminResaleException(_friendly(e, 'remove the listing'));
    }
  }

  /// Newest first.
  Future<List<FraudAlertEntry>> fetchAlerts() async {
    try {
      final rows = await Supabase.instance.client
          .from('fraud_alerts')
          .select('''
            alert_id, alert_type, source, severity, status, user_id, event_id,
            ticket_id, listing_id, details, created_at, reviewed_at,
            resolution_note,
            users(full_name, email),
            events(title)
          ''')
          .order('created_at', ascending: false) as List;
      return rows
          .map((r) => FraudAlertEntry.fromRow(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminResaleException(_friendly(e, 'load fraud alerts'));
    }
  }

  /// Moves an alert to [status] (open | reviewing | resolved | dismissed),
  /// recording who reviewed it and an optional [note].
  Future<void> updateAlert(String alertId, String status, {String? note}) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_update_fraud_alert',
        params: {'p_alert_id': alertId, 'p_status': status, 'p_note': note},
      );
    } on PostgrestException catch (e) {
      throw AdminResaleException(_friendly(e, 'update the alert'));
    }
  }

  String _friendly(PostgrestException e, String action) {
    // PGRST202 = function missing, PGRST205 / 42P01 = table missing: the SQL
    // file hasn't been run on this Supabase project yet.
    if (e.code == 'PGRST202' || e.code == 'PGRST205' || e.code == '42P01') {
      return 'Could not $action: run supabase/fraud_alerts.sql in the Supabase SQL Editor first.';
    }
    return 'Could not $action: ${e.message}';
  }
}
