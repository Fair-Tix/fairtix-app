import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the Light / Dark choice for the redesigned (Mahilum) screens and
/// remembers it between launches.
///
/// On the phone app the first launch is always Dark; on web it follows the
/// device setting. After the person flips the
/// switch, their explicit choice is saved and used from then on.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _storageKey = 'fairtix_theme_mode';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  bool _isDark = !kIsWeb ||
      ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  Future<void> _pendingWrite = Future<void>.value();

  bool get isDark => _isDark;

  /// Call once from main() before runApp so the first frame is already in the
  /// saved mode (no light-to-dark flash).
  Future<void> load() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved == 'dark') _isDark = true;
      if (saved == 'light') _isDark = false;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'FairTix theme controller',
          context: ErrorDescription('while restoring the saved theme mode'),
        ),
      );
    }
  }

  Future<void> setDark(bool value) async {
    if (value == _isDark) return;
    _isDark = value;
    notifyListeners();
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _storage.write(key: _storageKey, value: value ? 'dark' : 'light');
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'FairTix theme controller',
            context: ErrorDescription('while saving the selected theme mode'),
          ),
        );
      }
    });
    await _pendingWrite;
  }

  Future<void> toggle() => setDark(!_isDark);
}

/// Placed above MaterialApp so any screen that reads [FairTixPalette.of]
/// rebuilds the moment the switch is flipped.
class FairTixThemeScope extends InheritedNotifier<ThemeController> {
  const FairTixThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);
}
