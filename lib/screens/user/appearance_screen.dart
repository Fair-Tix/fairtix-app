import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/fairtix_palette.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/ft_dark_ui.dart' show FtColors;
import '../../widgets/ft_dashboard_ui.dart' show FtPressScale;
import '../../widgets/ft_profile_ui.dart'
    show FtPaletteBackground, ftOverlayStyle;

/// "Appearance" screen, opened from Profile > Settings. Lets the person
/// choose between Dark (the default after install) and Light. The choice is
/// applied immediately and saved on the device by [ThemeController].
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final controller = ThemeController.instance;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ftOverlayStyle(p),
      child: Scaffold(
        backgroundColor: p.gradientBottom,
        body: FtPaletteBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: 'Appearance',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Choose how FairTix looks on this device.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      height: 1.4,
                      color: p.textSoft,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ModeOption(
                    title: 'Dark',
                    subtitle: 'Deep purple background. Easy on the eyes at '
                        'night and in dim venues.',
                    preview: FairTixPalette.dark,
                    selected: p.isDark,
                    onTap: () => controller.setDark(true),
                  ),
                  const SizedBox(height: 14),
                  _ModeOption(
                    title: 'Light',
                    subtitle: 'Soft lavender background with dark text, '
                        'better for bright daylight.',
                    preview: FairTixPalette.light,
                    selected: !p.isDark,
                    onTap: () => controller.setDark(false),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 17, color: p.textSoft),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'FairTix starts in Dark after you install it. '
                          'Your choice is saved on this device.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            height: 1.4,
                            color: p.textSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round back button on the left, title centered. Follows the active mode.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              child: FtPressScale(
                onTap: onBack,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.surface,
                    border: Border.all(color: p.border),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 26,
                    color: p.textStrong,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: p.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable mode: a small preview of that mode, its name and a short
/// description, and a radio mark on the right.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;

  /// The palette this option shows in its thumbnail (not the active one).
  final FairTixPalette preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? FtColors.progressStart : p.border,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _Thumbnail(palette: preview),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: p.textStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.35,
                        color: p.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny phone-screen sketch drawn with the given palette.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.palette});

  final FairTixPalette palette;

  Widget _bar(double? width, double height, Color color) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.gradientTop, palette.gradientBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: FtColors.progressStart,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: _bar(null, 6, palette.textStrong)),
            ],
          ),
          const SizedBox(height: 9),
          _bar(null, 5, palette.textSoft),
          const SizedBox(height: 4),
          _bar(30, 5, palette.textSoft),
          const Spacer(),
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.border),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? FtColors.progressStart : Colors.transparent,
        border: Border.all(
          color: selected ? FtColors.progressStart : p.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
