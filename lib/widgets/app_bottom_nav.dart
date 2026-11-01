import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';

/// Bottom navigation bar for the main app shell, dark design.
///
/// Shows Home / My Tickets / Resale. The shell still has a fourth page,
/// Profile (index 3); it is opened from the profile circle on the Home
/// header, and while it is showing no item here is highlighted.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

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

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FtColors.bgBottom,
        border: Border(top: BorderSide(color: FtColors.otpBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final active = index == currentIndex;
              final target = active ? FtColors.progressEnd : FtColors.hint;
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
