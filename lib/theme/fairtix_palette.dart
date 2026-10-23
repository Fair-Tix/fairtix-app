import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Colors for the redesigned (Mahilum) screens, in Light and Dark.
///
/// Values are sampled straight from the design files. Each redesigned screen
/// adds the tokens it needs here, so the palette grows one screen at a time.
///
/// Use it inside build():  `final p = FairTixPalette.of(context);`
class FairTixPalette {
  const FairTixPalette({
    required this.isDark,
    required this.background,
    required this.backgroundGlow,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentLabel,
    required this.primary,
    required this.progressTrack,
    required this.switchTrack,
    required this.danger,
    required this.dangerSurface,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.warningBorder,
    required this.cameraSurface,
    required this.successCard,
    required this.successIcon,
    required this.dangerCard,
    required this.dangerIcon,
  });

  final bool isDark;

  /// Page background.
  final Color background;

  /// Soft radial glow at the top of the page.
  final Color backgroundGlow;

  /// Cards and secondary (outlined) buttons.
  final Color surface;

  /// Hairline border around cards and outlined buttons.
  final Color border;

  /// Headings and wordmark.
  final Color textPrimary;

  /// Subtitles and body copy.
  final Color textSecondary;

  /// Small purple labels (e.g. "FOR ORGANIZERS").
  final Color accentLabel;

  /// Brand purple used for fills, progress and the switch knob.
  final Color primary;

  /// Empty part of a progress bar.
  final Color progressTrack;

  /// Background of the light/dark switch.
  final Color switchTrack;

  /// Error text and borders (sampled from the Rejected scanner design).
  final Color danger;

  /// Soft fill behind rejected / error states (scanner "Ticket rejected").
  final Color dangerSurface;

  /// Green used for ticks, revenue figures and "Valid ticket".
  final Color success;

  /// Soft fill behind success icons and the "Valid ticket" card.
  final Color successSurface;

  /// Amber used for the lock / warning banners on the dashboard.
  final Color warning;

  /// Fill and border of the warning banner.
  final Color warningSurface;
  final Color warningBorder;

  /// Camera frame on the QR scanner screens.
  final Color cameraSurface;

  /// "Valid ticket" result card and the round tick badge inside it.
  final Color successCard;
  final Color successIcon;

  /// "Ticket rejected" result card and the round cross badge inside it.
  final Color dangerCard;
  final Color dangerIcon;

  /// Primary call-to-action gradient. Identical in Light and Dark.
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8755F2), Color(0xFF712EDC)],
  );

  static const FairTixPalette light = FairTixPalette(
    isDark: false,
    background: Color(0xFFF6F3FF),
    backgroundGlow: Color(0xFFDFD5FA),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFDCD2F5),
    textPrimary: Color(0xFF1A1033),
    textSecondary: Color(0xFF6B5A9E),
    accentLabel: Color(0xFF6D28D9),
    primary: Color(0xFF7C3AED),
    progressTrack: Color(0xFFEDE7FF),
    switchTrack: Color(0xFFE4DBFB),
    danger: Color(0xFFDC2626),
    dangerSurface: Color(0xFFFEE2E2),
    success: Color(0xFF15803D),
    successSurface: Color(0xFFDCFCE7),
    warning: Color(0xFFB45309),
    warningSurface: Color(0xFFFDF3E3),
    warningBorder: Color(0xFFF2D9B3),
    // Light scanner values are derived from the light tokens above; the dark
    // ones below are sampled from the design.
    cameraSurface: Color(0xFF1A1033),
    successCard: Color(0xFFDCFCE7),
    successIcon: Color(0xFFBBF7D0),
    dangerCard: Color(0xFFFEE2E2),
    dangerIcon: Color(0xFFFECACA),
  );

  static const FairTixPalette dark = FairTixPalette(
    isDark: true,
    background: Color(0xFF0B0720),
    backgroundGlow: Color(0xFF231259),
    surface: Color(0xFF150F36),
    border: Color(0xFF2E2266),
    textPrimary: Color(0xFFF3EEFF),
    textSecondary: Color(0xFFA592D9),
    accentLabel: Color(0xFFA78BFA),
    primary: Color(0xFF7C3AED),
    progressTrack: Color(0xFF2A1C66),
    switchTrack: Color(0xFF2A1C66),
    danger: Color(0xFFFF7C98),
    dangerSurface: Color(0xFF29152E),
    success: Color(0xFF4ADE80),
    successSurface: Color(0xFF1D2E41),
    warning: Color(0xFFF59E0B),
    warningSurface: Color(0xFF2A1F2E),
    warningBorder: Color(0xFF644830),
    cameraSurface: Color(0xFF120A30),
    successCard: Color(0xFF14272E),
    successIcon: Color(0xFF1C423A),
    dangerCard: Color(0xFF29152E),
    dangerIcon: Color(0xFF4B263F),
  );

  /// The palette for the current mode. Registers the caller so it rebuilds
  /// when the light/dark switch changes.
  static FairTixPalette of(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<FairTixThemeScope>()
        ?.notifier;
    return (controller?.isDark ?? false) ? dark : light;
  }
}
