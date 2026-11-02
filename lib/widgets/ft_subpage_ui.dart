import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';
import 'ft_dashboard_ui.dart' show FtBackButton;
import 'ft_registration_ui.dart' show FtEntrance;

/// Shared layout for the dark sub-screens opened from the Profile tab and
/// similar pushed pages: round back button with a centered title, a scrolling
/// body, and an optional bottom bar (divider + main button) that stays above
/// the keyboard and the safe area.
class FtSubpageScaffold extends StatelessWidget {
  const FtSubpageScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.body,
    this.bottomButton,
    this.bottomFooter,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> body;

  /// Main action pinned to the bottom (e.g. "Update Password").
  final Widget? bottomButton;

  /// Optional quiet line under the button.
  final Widget? bottomFooter;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: FtColors.bgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: FtColors.bgBottom,
        body: FtBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: FtEntrance(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FtPageHeader(title: title, onBack: onBack),
                          const SizedBox(height: 22),
                          ...body,
                        ],
                      ),
                    ),
                  ),
                ),
                if (bottomButton != null)
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: FtColors.divider)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          bottomButton!,
                          if (bottomFooter != null) ...[
                            const SizedBox(height: 14),
                            bottomFooter!,
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back button on the left, title centered.
class FtPageHeader extends StatelessWidget {
  const FtPageHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Opacity(
              opacity: onBack == null ? 0.5 : 1,
              child: FtBackButton(onTap: onBack ?? () {}),
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
