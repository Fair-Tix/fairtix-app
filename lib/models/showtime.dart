/// One showing of a per-day multi-day event: a date plus a start time.
///
/// A day can have several of them (e.g. Nov 28 at 3:00 PM and Nov 28 at
/// 7:00 PM). Each becomes its own event row with its own ticket pool (see
/// `create_event_with_days` in supabase/organizer_event_functions.sql).
/// [time] is a 24-hour "HH:MM" string in Philippine (Asia/Manila) time.
class Showtime {
  final DateTime date;
  final String time;

  const Showtime({required this.date, required this.time});

  /// The `{"date": "YYYY-MM-DD", "time": "HH:MM"}` shape the RPC expects.
  Map<String, String> toJson() => {
        'date': date.toIso8601String().split('T').first,
        'time': time,
      };
}

/// "15:00" or "15:00:00" (what Postgres returns for a `time` column) ->
/// "3:00 PM". Returns null when [raw] is null or not a valid time.
String? formatClockTime(String? raw) {
  final parts = parseClockTime(raw);
  if (parts == null) return null;
  final hour = parts.hour;
  final minute = parts.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:$minute $suffix';
}

/// Parses "HH:MM" / "HH:MM:SS" into its hour and minute, or null.
({int hour, int minute})? parseClockTime(String? raw) {
  if (raw == null) return null;
  final pieces = raw.trim().split(':');
  if (pieces.length < 2) return null;
  final hour = int.tryParse(pieces[0]);
  final minute = int.tryParse(pieces[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

/// [date] at the clock time [raw] ("HH:MM"), or [date] unchanged when [raw]
/// is missing/invalid. Used so resale cutoffs follow the real start time.
DateTime combineDateAndTime(DateTime date, String? raw) {
  final parts = parseClockTime(raw);
  if (parts == null) return date;
  return DateTime(date.year, date.month, date.day, parts.hour, parts.minute);
}

/// "3:00 PM" -> "15:00" style string from hour/minute (for the RPC).
String clockTimeString(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
