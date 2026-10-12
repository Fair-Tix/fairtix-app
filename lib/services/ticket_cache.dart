import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What gets saved to the phone: the raw `public.tickets` rows (already
/// joined with tier/event, exactly as TicketRepository fetched them) plus
/// the active resale prices, so [Ticket.fromRow] can rebuild the same
/// tickets later with no network.
class TicketCacheSnapshot {
  const TicketCacheSnapshot({
    required this.rows,
    required this.resalePrices,
    required this.ownerName,
    required this.savedAt,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, double> resalePrices;
  final String ownerName;
  final DateTime savedAt;
}

/// Persists the signed-in user's tickets (including each QR token) to
/// encrypted device storage — Android Keystore / iOS Keychain via
/// `flutter_secure_storage` — so the wallet and QR codes are still
/// viewable with no connection, even after the app is restarted.
///
/// Snapshots are keyed per user id, so one account's tickets are never
/// shown to another account on the same phone.
///
/// Every method swallows storage errors on purpose: a broken or
/// unavailable keystore must never break the wallet itself. A failed save
/// just means no offline copy; a failed load behaves like "nothing cached".
class TicketCache {
  TicketCache._();
  static final TicketCache instance = TicketCache._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Bump the version suffix if the stored shape ever changes, so old
  // snapshots are ignored instead of crashing the decoder.
  String _key(String userId) => 'ticket_cache_v1_$userId';

  Future<void> save(String userId, TicketCacheSnapshot snapshot) async {
    try {
      await _storage.write(
        key: _key(userId),
        value: jsonEncode({
          'savedAt': snapshot.savedAt.toIso8601String(),
          'ownerName': snapshot.ownerName,
          'rows': snapshot.rows,
          'resale': snapshot.resalePrices,
        }),
      );
    } catch (_) {
      // No offline copy this time; the live data is unaffected.
    }
  }

  Future<TicketCacheSnapshot?> load(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final rows = (json['rows'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final resale = (json['resale'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      );

      return TicketCacheSnapshot(
        rows: rows,
        resalePrices: resale,
        ownerName: (json['ownerName'] as String?) ?? 'FairTix User',
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } catch (_) {
      // Nothing useful to do if the delete fails.
    }
  }
}
