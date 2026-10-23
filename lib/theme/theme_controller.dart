import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the Light / Dark choice for the redesigned (Mahilum) screens and
/// remembers it between launches.
///
/// First launch follows the device setting; after the person flips the
/// switch, their explicit choice is saved and used from then on.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _storageKey = 'fairtix_theme_mode';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  bool _isDark =
      ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  bool get isDark => _isDark;

  /// Call once from main() before runApp so the first frame is already in the
  /// saved mode (no light-to-dark flash).
  Future<void> load() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved == 'dark') _isDark = true;
      if (saved == 'light') _isDark = false;
    } catch (_) {
      // Storage unavailable (private browsing, etc.): keep the device default.
    }
  }

  Future<void> setDark(bool value) async {
    if (value == _isDark) return;
    _isDark = value;
    notifyListeners();
    try {
      await _storage.write(key: _storageKey, value: value ? 'dark' : 'light');
    } catch (_) {
      // The switch still works for this session even if saving fails.
    }
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
