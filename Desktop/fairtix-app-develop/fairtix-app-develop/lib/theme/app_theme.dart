import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central place for FairTix's colors, gradients, and text styles.
/// Matches the purple gradient look from the Figma designs.
class AppColors {
  AppColors._();

  static const Color gradientTop = Color(0xFF6A28E0);
  static const Color gradientBottom = Color(0xFF9B4DFF);
  static const Color blobLight = Color(0x33FFFFFF);

  static const Color white = Color(0xFFFFFFFF);
  static const Color subtleWhite = Color(0xB3FFFFFF); // ~70% opacity
  static const Color faintWhite = Color(0x80FFFFFF); // ~50% opacity
  static const Color fieldFill = Color(0x26FFFFFF); // ~15% opacity
  static const Color fieldBorder = Color(0x4DFFFFFF); // ~30% opacity

  static const Color primaryText = Color(0xFF6A28E0);

  // Light-screen palette (Registration, Dashboard)
  static const Color pageBackground = Color(0xFFF7F6FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1C1526);
  static const Color textMuted = Color(0xFF8B87A0);
  static const Color inputFillLight = Color(0xFFF1EFF7);
  static const Color inputBorderLight = Color(0xFFE3E0EE);
  static const Color accentPurple = Color(0xFF7C3AED);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color pendingDot = Color(0xFFD8D4E6);

  static const Color error = Color(0xFFE0433D);
  static const Color errorBackground = Color(0xFFFDECEC);
  static const Color warningBackground = Color(0xFFFDF3E0);
}

class AppGradients {
  AppGradients._();

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gradientTop, AppColors.gradientBottom],
  );

  // Used for header bars and primary CTA buttons on light screens
  // (Continue, Submit for Verification, Take Selfie).
  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.gradientTop, AppColors.gradientBottom],
  );

  // Used for "result" / confirmation screens specifically — Ticket
  // Confirmed, Account Activated, Ticket Sold, Ticket Listed for Resale,
  // and any future screen of that kind. Distinct from the general
  // [background] gradient used across onboarding/auth.
  static const LinearGradient confirmation = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 1.0],
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
  );
}

class AppTextStyles {
  AppTextStyles._();

  // Kept as a plain string literal (rather than deriving it from
  // GoogleFonts.geist().fontFamily) so every TextStyle below can stay
  // `const` — matching it against a runtime value would force every
  // `const Text(..., style: AppTextStyles.xxx)` call across the app to
  // drop `const`, the same const-with-non-const problem as sample_events.
  // This is the exact family name Google Fonts registers Geist under;
  // buildAppTheme() below calls GoogleFonts.geist() once to actually
  // fetch/register it so this name resolves to the real font at runtime.
  static const String _fontFamily = 'Geist';

  static const TextStyle logo = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    color: AppColors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle tagline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.subtleWhite,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.subtleWhite,
  );

  static const TextStyle fieldInput = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.white,
  );

  static const TextStyle link = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.subtleWhite,
  );

  static const TextStyle primaryButton = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
  );

  static const TextStyle footerText = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.faintWhite,
  );

  // Light-screen (Registration, Dashboard) styles
  static const TextStyle screenTitleLight = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  static const TextStyle fieldLabelLight = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const TextStyle fieldInputLight = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle cardLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.4,
  );
}

ThemeData buildAppTheme() {
  // Triggers google_fonts to fetch (and cache) the real Geist font file
  // and register it under the 'Geist' family name — every `TextStyle`
  // above that references AppTextStyles._fontFamily ('Geist') then
  // resolves to the real font once it finishes loading.
  GoogleFonts.geist();

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppTextStyles._fontFamily,
    scaffoldBackgroundColor: AppColors.gradientTop,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gradientTop,
      brightness: Brightness.light,
    ),
  );
}
