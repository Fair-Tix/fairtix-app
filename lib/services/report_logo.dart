import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// Asset used in the header of exported PDF reports. Use the logo with a
/// white/transparent background (the dark app-icon logo.png would look wrong
/// on white paper). `assets/icon/` is already declared in pubspec.yaml.
const String fairtixReportLogoAsset = 'assets/icon/fairtix_logo.png';

Uint8List? _cachedLogo;

/// Loads the report logo. Only a successful load is cached, so a missing
/// asset is retried on the next export. Returns null (and prints why) if the
/// asset can't be loaded, so a report still exports with a text wordmark.
Future<Uint8List?> loadReportLogo() async {
  if (_cachedLogo != null) return _cachedLogo;
  try {
    final data = await rootBundle.load(fairtixReportLogoAsset);
    _cachedLogo = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (e) {
    debugPrint('Report logo not loaded ($fairtixReportLogoAsset): $e');
    _cachedLogo = null;
  }
  return _cachedLogo;
}
