import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/fairtix_palette.dart';

/// Shared building blocks for the FairTix look (splash, login, and the
/// screens that follow in the UI rework). Colors and sizes are taken from the
/// reference designs so every screen reads as one identity.
///
/// [FtColors] and [FtText] are the Dark values. The auth / registration
/// widgets in this file and in ft_registration_ui.dart draw through
/// [FtAuthTheme], which is Dark unless the screen opts in to the Light / Dark
/// switch with `followTheme: true` on its scaffold.

class FtColors {
  FtColors._();

  // Same background as the splash screen.
  static const Color bgTop = Color(0xFF241354);
  static const Color bgBottom = Color(0xFF08051B);

  static const Color fieldFill = Color(0xFF150F36);
  static const Color fieldBorder = Color(0xFF2E2266);
  static const Color fieldBorderFocused = Color(0xFF8B5CF6);
  static const Color divider = Color(0xFF241B50);

  static const Color lavender = Color(0xFFA592D9); // subtitles, secondary text
  static const Color hint = Color(0xFF7F72B0); // placeholders
  static const Color accent = Color(0xFFA78BFA); // links

  static const Color danger = Color(0xFFFF7C98);
  static const Color dangerSurface = Color(0xFF29152E);
  static const Color success = Color(0xFF4ADE80);
  static const Color successSurface = Color(0xFF14272E);

  static const Color buttonStart = Color(0xFF8755F2);
  static const Color buttonEnd = Color(0xFF712EDC);
  static const Color glow = Color(0xFF7C3AED);

  // Registration flow: progress bar and the circular back button.
  static const Color progressTrack = Color(0xFF302064);
  static const Color progressStart = Color(0xFF8138ED);
  static const Color progressEnd = Color(0xFFC69AFF);
  static const Color circleButtonFill = Color(0xFF1F1548);
  static const Color circleButtonBorder = Color(0xFF3A2D7A);
  static const Color lavenderBright = Color(0xFFC9BCF0); // legal-text links

  // Step 2 (email verification) palette, taken from its design spec.
  static const Color otpFill = Color(0xFF15102D);
  static const Color otpBorder = Color(0xFF302064);
  static const Color otpActive = Color(0xFFC69AFF);
  static const Color otpSecondary = Color(0xFFB7A5E8);
  static const Color otpButtonEnd = Color(0xFF7028DB);
}

class FtText {
  FtText._();

  static TextStyle title() => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: Colors.white,
  );

  static TextStyle subtitle() => GoogleFonts.plusJakartaSans(
    fontSize: 14.5,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: FtColors.lavender,
  );

  static TextStyle label() => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle input() => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );

  static TextStyle hint() => input().copyWith(color: FtColors.hint);

  static TextStyle error() => GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: FtColors.danger,
  );

  static TextStyle button() => GoogleFonts.plusJakartaSans(
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );

  static TextStyle link() => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: FtColors.accent,
  );

  static TextStyle footer() => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: FtColors.lavender,
  );

  static TextStyle banner() => GoogleFonts.plusJakartaSans(
    fontSize: 13.5,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle stepLabel() => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: FtColors.lavender,
  );

  static TextStyle legal() => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: FtColors.lavender,
  );

  static TextStyle legalLink() => legal().copyWith(
    fontWeight: FontWeight.w700,
    color: FtColors.lavenderBright,
  );

  /// Every style above, so the splash screen can pre-load the fonts and the
  /// first screen after it never swaps fonts mid-fade.
  static List<TextStyle> warmUpStyles() => [
    title(),
    subtitle(),
    label(),
    input(),
    error(),
    button(),
    link(),
    footer(),
    banner(),
    stepLabel(),
    legal(),
    legalLink(),
  ];
}

/// The colors the auth and registration building blocks draw with.
///
/// [dark] is the original look (the [FtColors] values, unchanged). The Light
/// theme is built from [FairTixPalette], so these screens match the
/// dashboard, profile and loading screen when the switch is on Light.
///
/// A screen opts in by passing `followTheme: true` to [FtAuthScaffold] or
/// FtRegistrationScaffold. The scaffold then hands the right theme to every
/// field, button, banner and link below it. Without the flag (or outside a
/// scaffold) everything stays Dark, so screens that have not been reworked
/// for Light yet look exactly as before.
class FtAuthTheme {
  const FtAuthTheme({
    required this.isDark,
    required this.bgTop,
    required this.bgBottom,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldBorderFocused,
    required this.divider,
    required this.titleColor,
    required this.subtitleColor,
    required this.labelColor,
    required this.inputColor,
    required this.hintColor,
    required this.accent,
    required this.danger,
    required this.dangerSurface,
    required this.success,
    required this.successSurface,
    required this.bannerTextColor,
    required this.iconColor,
    required this.circleFill,
    required this.circleBorder,
    required this.circleIcon,
    required this.progressTrack,
    required this.legalColor,
    required this.legalLinkColor,
    required this.stepLabelColor,
    required this.glowAlpha,
    required this.surfaceFill,
    required this.surfaceBorder,
    required this.activeAccent,
    required this.secondaryText,
    required this.cardFill,
    required this.uploadFill,
    required this.selfieCaption,
  });

  final bool isDark;

  /// Page gradient (top to ~60% of the screen) and the color below it.
  final Color bgTop;
  final Color bgBottom;

  /// Text fields, and the line above the bottom button bar.
  final Color fieldFill;
  final Color fieldBorder;
  final Color fieldBorderFocused;
  final Color divider;

  final Color titleColor;
  final Color subtitleColor;
  final Color labelColor;
  final Color inputColor;
  final Color hintColor;

  /// Links and the text cursor.
  final Color accent;

  final Color danger;
  final Color dangerSurface;
  final Color success;
  final Color successSurface;
  final Color bannerTextColor;

  /// Icons inside fields (the show / hide password eye).
  final Color iconColor;

  /// Round back button.
  final Color circleFill;
  final Color circleBorder;
  final Color circleIcon;

  /// Empty part of the registration progress bar.
  final Color progressTrack;

  /// "By continuing you agree to..." text and its links.
  final Color legalColor;
  final Color legalLinkColor;

  /// "Step 1 of 5".
  final Color stepLabelColor;

  /// Opacity of the purple glow under the main button.
  final double glowAlpha;

  /// Registration Steps 2-5: code boxes, cards, pills and the selfie frame
  /// (fill and hairline border), plus the lit-up purple used for active
  /// borders, icons and accent text.
  final Color surfaceFill;
  final Color surfaceBorder;
  final Color activeAccent;

  /// Body copy under headings on those steps.
  final Color secondaryText;

  /// The translucent "You're almost there" card, the dashed ID upload area,
  /// and the caption inside the selfie frame.
  final Color cardFill;
  final Color uploadFill;
  final Color selfieCaption;

  static const FtAuthTheme dark = FtAuthTheme(
    isDark: true,
    bgTop: FtColors.bgTop,
    bgBottom: FtColors.bgBottom,
    fieldFill: FtColors.fieldFill,
    fieldBorder: FtColors.fieldBorder,
    fieldBorderFocused: FtColors.fieldBorderFocused,
    divider: FtColors.divider,
    titleColor: Colors.white,
    subtitleColor: FtColors.lavender,
    labelColor: Colors.white,
    inputColor: Colors.white,
    hintColor: FtColors.hint,
    accent: FtColors.accent,
    danger: FtColors.danger,
    dangerSurface: FtColors.dangerSurface,
    success: FtColors.success,
    successSurface: FtColors.successSurface,
    bannerTextColor: Colors.white,
    iconColor: FtColors.lavender,
    circleFill: FtColors.circleButtonFill,
    circleBorder: FtColors.circleButtonBorder,
    circleIcon: Colors.white,
    progressTrack: FtColors.progressTrack,
    legalColor: FtColors.lavender,
    legalLinkColor: FtColors.lavenderBright,
    stepLabelColor: FtColors.lavender,
    glowAlpha: 0.35,
    surfaceFill: FtColors.otpFill,
    surfaceBorder: FtColors.otpBorder,
    activeAccent: FtColors.otpActive,
    secondaryText: FtColors.otpSecondary,
    cardFill: Color(0x9915102D), // otpFill at 60%
    uploadFill: Color(0xFF291C60),
    selfieCaption: Color(0xFFEDE7FF),
  );

  /// Light values, all taken from the shared palette so nothing here is a
  /// one-off color.
  factory FtAuthTheme._light(FairTixPalette p) => FtAuthTheme(
    isDark: false,
    bgTop: p.gradientTop,
    bgBottom: p.gradientBottom,
    fieldFill: p.surface,
    fieldBorder: p.border,
    fieldBorderFocused: p.primary,
    divider: p.border,
    titleColor: p.textStrong,
    subtitleColor: p.textSoft,
    labelColor: p.textStrong,
    inputColor: p.textStrong,
    hintColor: p.textSoft.withValues(alpha: 0.72),
    accent: p.accentLabel,
    danger: p.danger,
    dangerSurface: p.dangerSurface,
    success: p.success,
    successSurface: p.successSurface,
    bannerTextColor: p.textStrong,
    iconColor: p.textSoft,
    circleFill: p.surface,
    circleBorder: p.border,
    circleIcon: p.textStrong,
    progressTrack: p.progressTrack,
    legalColor: p.textSoft,
    legalLinkColor: p.accentLabel,
    stepLabelColor: p.textSoft,
    glowAlpha: 0.25,
    surfaceFill: p.surface,
    surfaceBorder: p.border,
    activeAccent: p.accentLabel,
    secondaryText: p.textSoft,
    cardFill: p.card,
    uploadFill: p.tileFill,
    selfieCaption: p.textSoft,
  );

  static FtAuthTheme fromPalette(FairTixPalette p) =>
      p.isDark ? dark : FtAuthTheme._light(p);

  /// The theme for the current Light / Dark switch. Use this in a screen's own
  /// build(), above the scaffold (e.g. for the links in the footer).
  static FtAuthTheme live(BuildContext context) =>
      fromPalette(FairTixPalette.of(context));

  /// The theme the surrounding scaffold handed down (Dark when there is none).
  /// Use this inside the shared widgets.
  static FtAuthTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FtAuthThemeScope>()?.theme ??
      dark;

  /// Status bar and navigation bar styling for this theme.
  SystemUiOverlayStyle get overlayStyle =>
      (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: bgBottom,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      );

  // The text styles, in this theme's colors.
  TextStyle title() => FtText.title().copyWith(color: titleColor);
  TextStyle subtitle() => FtText.subtitle().copyWith(color: subtitleColor);
  TextStyle label() => FtText.label().copyWith(color: labelColor);
  TextStyle input() => FtText.input().copyWith(color: inputColor);
  TextStyle hint() => FtText.input().copyWith(color: hintColor);
  TextStyle error() => FtText.error().copyWith(color: danger);
  TextStyle link() => FtText.link().copyWith(color: accent);
  TextStyle footer() => FtText.footer().copyWith(color: subtitleColor);
  TextStyle banner() => FtText.banner().copyWith(color: bannerTextColor);
  TextStyle stepLabel() => FtText.stepLabel().copyWith(color: stepLabelColor);
  TextStyle legal() => FtText.legal().copyWith(color: legalColor);
  TextStyle legalLink() => FtText.legalLink().copyWith(color: legalLinkColor);
}

/// Hands an [FtAuthTheme] to everything below an auth / registration
/// scaffold. Read it with [FtAuthTheme.of].
class FtAuthThemeScope extends InheritedWidget {
  const FtAuthThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final FtAuthTheme theme;

  @override
  bool updateShouldNotify(FtAuthThemeScope oldWidget) =>
      oldWidget.theme.isDark != theme.isDark;
}

/// Page gradient in the colors of an [FtAuthTheme]. Same stops as
/// [FtBackground], which this matches exactly in Dark.
class FtAuthBackground extends StatelessWidget {
  const FtAuthBackground({super.key, required this.theme, required this.child});

  final FtAuthTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.6],
          colors: [theme.bgTop, theme.bgBottom],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}

/// Full-screen dark gradient. The color stops follow the login reference,
/// where the purple fades out by roughly the middle of the screen.
class FtBackground extends StatelessWidget {
  const FtBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.6],
          colors: [FtColors.bgTop, FtColors.bgBottom],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}

/// The FT ticket from `assets/logo/ft_lightlogo.png`, sized by the width of
/// the visible ticket. The PNG is a square with transparent padding; layout
/// uses only the ticket's bounds (the image itself is not cropped or scaled
/// differently), so it lines up with the screen's left margin.
class FtLogo extends StatelessWidget {
  const FtLogo({super.key, this.ticketWidth = 76, this.dark = false});

  final double ticketWidth;

  /// True = the purple logo for light backgrounds (Light mode). Uses the same
  /// crop as the light logo, so both PNGs must share the same canvas layout.
  final bool dark;

  static const String asset = 'assets/logo/ft_lightlogo.png';
  static const String darkAsset = 'assets/logo/ft_darklogo.png';

  // Visible-ticket bounds inside the 1254 x 1254 PNG.
  static const double _left = 208 / 1254;
  static const double _top = 309 / 1254;
  static const double _w = 865 / 1254;
  static const double _h = 598 / 1254;

  @override
  Widget build(BuildContext context) {
    final side = ticketWidth / _w;
    return SizedBox(
      width: ticketWidth,
      height: side * _h,
      child: OverflowBox(
        minWidth: side,
        maxWidth: side,
        minHeight: side,
        maxHeight: side,
        alignment: Alignment(
          (_left / (1 - _w)) * 2 - 1,
          (_top / (1 - _h)) * 2 - 1,
        ),
        child: Image.asset(
          dark ? darkAsset : asset,
          width: side,
          height: side,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          semanticLabel: 'FairTix',
        ),
      ),
    );
  }
}

/// Page layout shared by the auth screens: logo, heading and subtitle at the
/// top inside a scroll view (so the keyboard never hides the active field),
/// and a bottom bar with a divider, the main button and a footer, anchored
/// above the safe area and the keyboard.
class FtAuthScaffold extends StatelessWidget {
  const FtAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.button,
    this.footer,
    this.followTheme = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> body;
  final Widget button;
  final Widget? footer;

  /// True = follow the Light / Dark switch (purple logo on light). False =
  /// always Dark, for screens that have not been reworked for Light yet.
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
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FtLogo(ticketWidth: 76, dark: !t.isDark),
                          const SizedBox(height: 30),
                          Semantics(
                            header: true,
                            child: Text(title, style: t.title()),
                          ),
                          const SizedBox(height: 8),
                          Text(subtitle, style: t.subtitle()),
                          const SizedBox(height: 30),
                          ...body,
                        ],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.divider)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          button,
                          if (footer != null) ...[
                            const SizedBox(height: 14),
                            footer!,
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

/// Labelled dark input. Set [isPassword] for a masked field with the eye
/// toggle on the right.
class FtTextField extends StatefulWidget {
  const FtTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.onSubmitted,
    this.enabled = true,
    this.inputFormatters,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  State<FtTextField> createState() => _FtTextFieldState();
}

class _FtTextFieldState extends State<FtTextField> {
  bool _obscured = true;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: 1),
  );

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: t.label()),
        const SizedBox(height: 10),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: widget.isPassword && _obscured,
          enableSuggestions: !widget.isPassword,
          autocorrect: !widget.isPassword,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          textCapitalization: widget.textCapitalization,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: t.input(),
          cursorColor: t.accent,
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.hintText,
            hintStyle: t.hint(),
            errorStyle: t.error(),
            errorMaxLines: 2,
            filled: true,
            fillColor: t.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 19,
            ),
            border: _border(t.fieldBorder),
            enabledBorder: _border(t.fieldBorder),
            disabledBorder: _border(t.fieldBorder),
            focusedBorder: _border(t.fieldBorderFocused),
            errorBorder: _border(t.danger),
            focusedErrorBorder: _border(t.danger),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: t.iconColor,
                      size: 22,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Full-width purple gradient pill with a soft glow. While [loading] it shows
/// a spinner and ignores taps, so a request can't be submitted twice. A null
/// [onPressed] (and not loading) renders it dimmed and inactive.
class FtGradientButton extends StatelessWidget {
  const FtGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(29);

    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? 'Loading' : label,
      excludeSemantics: true,
      child: Opacity(
        opacity: (onPressed == null && !loading) ? 0.55 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [FtColors.buttonStart, FtColors.buttonEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: FtColors.glow.withValues(alpha: t.glowAlpha),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: 58,
                width: double.infinity,
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(label, style: FtText.button()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline message box for form-level errors and success notices.
class FtBanner extends StatelessWidget {
  const FtBanner({super.key, required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final color = isError ? t.danger : t.success;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isError ? t.dangerSurface : t.successSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: t.banner())),
          ],
        ),
      ),
    );
  }
}
