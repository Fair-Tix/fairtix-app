import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown for any scanner-session-related failure (creating a session,
/// ending one, validating a staff PIN, or scanning a ticket).
class ScannerRepositoryException implements Exception {
  final String message;
  const ScannerRepositoryException(this.message);
}

/// A live scanner session for one event — the link + 4-digit PIN an
/// organizer hands to entry staff. Backed by `public.scanner_sessions`.
class ScannerSession {
  const ScannerSession({
    required this.sessionId,
    required this.eventId,
    required this.token,
    required this.pin,
    required this.expiresAt,
  });

  final String sessionId;
  final String eventId;
  final String token;
  final String pin;
  final DateTime expiresAt;

  /// The link entry staff open to reach the PIN-entry screen. Not yet
  /// backed by real deep-linking (see StaffPinEntryScreen docs) — for now
  /// staff paste this same string into that screen's "Scanner link"
  /// field, which extracts the token from it.
  String get link => 'https://fairtix.app/scan/$token';

  factory ScannerSession.fromRow(Map<String, dynamic> row) => ScannerSession(
        sessionId: row['session_id'] as String,
        eventId: row['event_id'] as String,
        token: row['session_token'] as String,
        pin: row['session_pin'] as String,
        expiresAt: DateTime.parse(row['expires_at'] as String),
      );
}

/// Result of a staff member entering a link + PIN — confirms which event
/// they're now scanning for.
class ScannerAccess {
  const ScannerAccess({
    required this.sessionId,
    required this.eventId,
    required this.eventTitle,
    required this.token,
    required this.pin,
  });

  final String sessionId;
  final String eventId;
  final String eventTitle;

  /// Kept alongside the validated access so [ScanOutcome]-producing scans
  /// can be authorized the same way, without asking staff to re-enter
  /// their PIN before every single scan.
  final String token;
  final String pin;
}

/// Result of scanning one ticket's QR code at the door.
enum ScanResult { valid, alreadyUsed, invalid, wrongEvent }

class ScanOutcome {
  const ScanOutcome({required this.result, this.eventTitle, this.tierName});

  final ScanResult result;
  final String? eventTitle;
  final String? tierName;

  bool get isAccepted => result == ScanResult.valid;

  String get headline => switch (result) {
        ScanResult.valid => 'Accepted',
        ScanResult.alreadyUsed => 'Rejected \u2014 Already Used',
        ScanResult.wrongEvent => 'Rejected \u2014 Wrong Event',
        ScanResult.invalid => 'Rejected \u2014 Invalid QR',
      };

  factory ScanOutcome.fromRow(Map<String, dynamic> row) {
    final result = switch (row['result'] as String) {
      'valid' => ScanResult.valid,
      'already_used' => ScanResult.alreadyUsed,
      'wrong_event' => ScanResult.wrongEvent,
      _ => ScanResult.invalid,
    };
    return ScanOutcome(
      result: result,
      eventTitle: row['event_title'] as String?,
      tierName: row['tier_name'] as String?,
    );
  }
}

/// Wraps the scanner-session RPCs in supabase/scanner_functions.sql:
/// generating/ending a session (organizer), and validating a staff
/// PIN + scanning tickets (entry staff — no FairTix account needed).
class ScannerRepository {
  ScannerRepository._();
  static final ScannerRepository instance = ScannerRepository._();

  /// Starts (or restarts) a scanner session for [eventId]. Any previous
  /// still-active session for the same event is automatically revoked
  /// server-side, so there's only ever one live link/PIN pair per event.
  Future<ScannerSession> createSession(String eventId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'generate_scanner_session',
        params: {'p_event_id': eventId},
      );
      final row = (result is List) ? result.first as Map<String, dynamic> : result as Map<String, dynamic>;
      return ScannerSession.fromRow(row);
    } on PostgrestException catch (e) {
      throw ScannerRepositoryException(e.message);
    }
  }

  Future<void> endSession(String sessionId) async {
    try {
      await Supabase.instance.client.rpc(
        'revoke_scanner_session',
        params: {'p_session_id': sessionId},
      );
    } on PostgrestException catch (e) {
      throw ScannerRepositoryException(e.message);
    }
  }

  /// Validates a staff-entered scanner link (or bare token) + PIN.
  /// Accepts either the full `https://fairtix.app/scan/<token>` link or
  /// just the token itself, since staff might paste either.
  Future<ScannerAccess> validateAccess({required String linkOrToken, required String pin}) async {
    final token = _extractToken(linkOrToken);
    try {
      final result = await Supabase.instance.client.rpc(
        'validate_scanner_session',
        params: {'p_token': token, 'p_pin': pin},
      );
      final rows = result is List ? result : [result];
      if (rows.isEmpty) {
        throw const ScannerRepositoryException('That link and PIN are invalid or have expired.');
      }
      final row = rows.first as Map<String, dynamic>;
      return ScannerAccess(
        sessionId: row['session_id'] as String,
        eventId: row['event_id'] as String,
        eventTitle: row['event_title'] as String,
        token: token,
        pin: pin,
      );
    } on PostgrestException catch (e) {
      throw ScannerRepositoryException(e.message);
    }
  }

  /// Scans one ticket's QR code under an already-[ScannerAccess]-validated
  /// session. This is where a valid ticket actually gets invalidated
  /// (flipped to used) server-side — see scan_ticket in
  /// supabase/scanner_functions.sql.
  Future<ScanOutcome> scanTicket({required ScannerAccess access, required String qrToken}) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'scan_ticket',
        params: {'p_token': access.token, 'p_pin': access.pin, 'p_qr_code_token': qrToken},
      );
      final row = (result is List) ? result.first as Map<String, dynamic> : result as Map<String, dynamic>;
      return ScanOutcome.fromRow(row);
    } on PostgrestException catch (e) {
      throw ScannerRepositoryException(e.message);
    }
  }

  String _extractToken(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    // Strip a trailing slash, then take whatever's after the last "/" so
    // both a bare token and a full link work.
    final withoutTrailingSlash = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    return withoutTrailingSlash.contains('/') ? withoutTrailingSlash.split('/').last : withoutTrailingSlash;
  }
}
