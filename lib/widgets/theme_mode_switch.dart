import 'package:flutter/material.dart';

import '../theme/fairtix_palette.dart';
import '../theme/theme_controller.dart';

/// Slide switch for Light / Dark mode.
///
/// Knob on the left with a sun = Light mode (off). Knob slides right and
/// turns into a moon = Dark mode (on). Drop it anywhere, e.g. in a top bar:
/// `const ThemeModeSwitch()`.
class ThemeModeSwitch extends StatelessWidget {
  const ThemeModeSwitch({super.key});

  static const double _width = 58;
  static const double _height = 32;
  static const double _knob = 24;
  static const Duration _duration = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final isDark = p.isDark;

    return Semantics(
      toggled: isDark,
      label: 'Dark mode',
      button: true,
      child: Tooltip(
        message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ThemeController.instance.toggle,
            child: AnimatedContainer(
              duration: _duration,
              curve: Curves.easeOutCubic,
              width: _width,
              height: _height,
              padding: const EdgeInsets.all((_height - _knob) / 2),
              decoration: BoxDecoration(
                color: p.switchTrack,
                borderRadius: BorderRadius.circular(_height),
                border: Border.all(
                  color: p.primary.withValues(alpha: isDark ? 0.45 : 0.25),
                ),
              ),
              child: AnimatedAlign(
                duration: _duration,
                curve: Curves.easeOutCubic,
                alignment:
                    isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: p.primary.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: _duration,
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: Tween<double>(begin: 0.85, end: 1).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      key: ValueKey<bool>(isDark),
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
