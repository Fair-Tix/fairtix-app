import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/fairtix_palette.dart';
import 'ft_dark_ui.dart';

/// Rounded filter chip used in the Resale Market's category row
/// (All / Concerts / Sports / Theater). The selected chip is filled with the
/// brand purple gradient. Draws with the surrounding [FtAuthTheme].
class ResaleFilterChip extends StatelessWidget {
  const ResaleFilterChip({super.key, required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: isSelected ? FairTixPalette.buttonGradient : null,
          color: isSelected ? null : t.surfaceFill,
          border: isSelected ? null : Border.all(color: t.surfaceBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected ? Colors.white : t.secondaryText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
