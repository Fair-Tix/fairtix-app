import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// How organizers reach FairTix.
///
/// Set [email] to the address that answers organizer questions. While it is
/// empty the organizer app has no way to contact FairTix, so the
/// "Help & Support" item stays out of the profile menu and the "request a
/// correction" guidance on the Profile page falls back to plain text.
class FairTixSupport {
  const FairTixSupport._();

  /// Official FairTix support address.
  static const String email = 'fairtix.support@gmail.com';

  static bool get isAvailable => email.trim().isNotEmpty;

  /// Opens the organizer's email app with a draft to FairTix. Returns false
  /// when nothing could be opened (no mail app, or no address configured),
  /// so the caller can offer to copy the address instead.
  static Future<bool> compose({String subject = '', String body = ''}) async {
    if (!isAvailable) return false;
    final query = [
      if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
      if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
    ].join('&');
    final uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      query: query.isEmpty ? null : query,
    );
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<void> copyEmail() =>
      Clipboard.setData(ClipboardData(text: email.trim()));
}
