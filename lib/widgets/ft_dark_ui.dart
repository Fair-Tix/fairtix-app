import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared building blocks for the dark FairTix look (splash, login, and the
/// screens that follow in the UI rework). Colors and sizes are taken from the
/// two reference designs so every screen reads as one identity.
///
/// These are always dark on purpose: they do not follow the Light/Dark switch
/// used by the organizer web screens.

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
  const FtLogo({super.key, this.ticketWidth = 76});

  final double ticketWidth;

  static const String asset = 'assets/logo/ft_lightlogo.png';

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
          asset,
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
  });

  final String title;
  final String subtitle;
  final List<Widget> body;
  final Widget button;
  final Widget? footer;

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
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FtLogo(ticketWidth: 76),
                        const SizedBox(height: 30),
                        Semantics(
                          header: true,
                          child: Text(title, style: FtText.title()),
                        ),
                        const SizedBox(height: 8),
                        Text(subtitle, style: FtText.subtitle()),
                        const SizedBox(height: 30),
                        ...body,
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: FtColors.divider)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: FtText.label()),
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
          style: FtText.input(),
          cursorColor: FtColors.accent,
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.hintText,
            hintStyle: FtText.hint(),
            errorStyle: FtText.error(),
            errorMaxLines: 2,
            filled: true,
            fillColor: FtColors.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 19,
            ),
            border: _border(FtColors.fieldBorder),
            enabledBorder: _border(FtColors.fieldBorder),
            disabledBorder: _border(FtColors.fieldBorder),
            focusedBorder: _border(FtColors.fieldBorderFocused),
            errorBorder: _border(FtColors.danger),
            focusedErrorBorder: _border(FtColors.danger),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: FtColors.lavender,
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
                color: FtColors.glow.withValues(alpha: 0.35),
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
    final color = isError ? FtColors.danger : FtColors.success;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isError ? FtColors.dangerSurface : FtColors.successSurface,
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
            Expanded(child: Text(message, style: FtText.banner())),
          ],
        ),
      ),
    );
  }
}
