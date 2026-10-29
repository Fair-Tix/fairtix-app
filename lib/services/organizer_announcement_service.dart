import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when an announcement could not be sent.
class OrganizerAnnouncementException implements Exception {
  final String message;
  const OrganizerAnnouncementException(this.message);

  @override
  String toString() => message;
}

/// Sends an announcement to everyone who holds a ticket to the signed-in
/// organizer's events. The work happens in `send_organizer_announcement`
/// (supabase/organizer_tools.sql), which checks that the organizer is approved
/// and subscribed and delivers it in-app, by email and as a push notification.
class OrganizerAnnouncementService {
  OrganizerAnnouncementService._();
  static final OrganizerAnnouncementService instance =
      OrganizerAnnouncementService._();

  /// Returns how many people it was sent to (0 when nobody has bought a
  /// ticket yet).
  Future<int> send({required String subject, required String message}) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'send_organizer_announcement',
        params: {'p_subject': subject.trim(), 'p_message': message.trim()},
      );
      return (result as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      throw OrganizerAnnouncementException(e.message);
    } catch (_) {
      throw const OrganizerAnnouncementException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }
}
