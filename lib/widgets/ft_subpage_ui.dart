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
    this.followTheme = false,
    this.titleAtEnd = false,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> body;

  /// True = the title sits at the right edge, in a quieter color, opposite the
  /// back button (the "List for resale" layout).
  final bool titleAtEnd;

  /// Main action pinned to the bottom (e.g. "Update Password").
  final Widget? bottomButton;

  /// Optional quiet line under the button.
  final Widget? bottomFooter;

  /// True = follow the Light / Dark switch. False = always Dark, for pages
  /// that have not been reworked for Light yet.
  final bool followTheme;

  @override
  Widget build(BuildContext context) {
    final t = followTheme ? FtAuthTheme.live(context) : FtAuthTheme.dark;
    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: t.overlayStyle,
        child: Scaffold(
          backgroundColor: t.bgBottom,
          body: FtAuthBackground(
            theme: t,
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
                            FtPageHeader(title: title, onBack: onBack, titleAtEnd: titleAtEnd),
                            const SizedBox(height: 22),
                            ...body,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (bottomButton != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: t.divider)),
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
      ),
    );
  }
}

/// Back button on the left, title centered.
class FtPageHeader extends StatelessWidget {
  const FtPageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.titleAtEnd = false,
  });

  final String title;
  final VoidCallback? onBack;
  final bool titleAtEnd;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
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
          Align(
            alignment: titleAtEnd ? Alignment.centerRight : Alignment.center,
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: titleAtEnd ? 18 : 19,
                  fontWeight: FontWeight.w800,
                  color: titleAtEnd ? t.secondaryText : t.titleColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
