import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/fairtix_palette.dart';
import 'ft_dark_ui.dart';

/// Bottom navigation bar for the main app shell, dark design.
///
/// Shows Home / My Tickets / Resale. The shell still has a fourth page,
/// Profile (index 3); it is opened from the profile circle on the Home
/// header, and while it is showing no item here is highlighted.
///
/// The bar follows the Light / Dark switch only on tabs that have been
/// converted to it (see [_lightReadyTabs]); every other tab keeps the dark
/// bar. Add a tab's index to that set when its screen supports Light mode.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Shell tab indexes whose screens already follow the Light / Dark switch.
  /// 0 = Home, 1 = My Tickets, 2 = Resale, 3 = Profile.
  static const Set<int> _lightReadyTabs = {0, 1, 2, 3};

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number_outlined,
      label: 'My Tickets',
    ),
    (
      icon: Icons.swap_horiz_rounded,
      activeIcon: Icons.swap_horiz_rounded,
      label: 'Resale',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 180);
    final p = _lightReadyTabs.contains(currentIndex)
        ? FairTixPalette.of(context)
        : FairTixPalette.dark;
    final inactive = p.isDark ? FtColors.hint : p.textSoft;

    return AnimatedContainer(
      duration: duration,
      decoration: BoxDecoration(
        // Dark keeps the page color; Light uses a white bar.
        color: p.isDark ? p.gradientBottom : p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final active = index == currentIndex;
              final target = active ? p.tileAccent : inactive;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label: item.label,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onTap(index),
                    splashColor: FtColors.progressStart.withValues(alpha: 0.12),
                    highlightColor: Colors.transparent,
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: target),
                      duration: duration,
                      builder: (context, color, _) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: active ? 1.1 : 1,
                            duration: duration,
                            curve: Curves.easeOut,
                            child: Icon(
                              active ? item.activeIcon : item.icon,
                              color: color,
                              size: 25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
