import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording while a sensitive screen (the
/// ticket QR code) is open.
///
/// On Android this sets the window's FLAG_SECURE (see MainActivity.kt):
/// screenshots come out blank/are refused, screen recordings show black,
/// and the app preview in the recent-apps list is hidden.
///
/// On platforms without a native handler (iOS, web, desktop) the calls are
/// harmless no-ops — iOS protection is not implemented yet.
class ScreenProtection {
  ScreenProtection._();

  static const MethodChannel _channel = MethodChannel('com.fairtix.fairtix_app/screen_protection');

  static Future<void> enable() => _setSecure(true);
  static Future<void> disable() => _setSecure(false);

  static Future<void> _setSecure(bool secure) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // No native handler on this platform.
    } on PlatformException {
      // Never let a protection failure break the ticket screen.
    }
  }
}
