import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/fairtix_palette.dart';
import 'theme_mode_switch.dart';
import 'top_glow_background.dart';

/// Shared building blocks for the redesigned (Mahilum) organizer screens that
/// sit on a centered card: Registration, OTP, Application Submitted,
/// Application Approved, Subscription Plan and Subscription Confirmation.
///
/// Everything reads [FairTixPalette], so Light and Dark both work.

/// Plus Jakarta Sans text style tied to the palette. All redesigned screens
/// use this font.
TextStyle orgText(
  FairTixPalette p, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double height = 1.4,
  double? letterSpacing,
  FontStyle? fontStyle,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    color: color ?? p.textPrimary,
  );
}

/// Full-screen page: page color + top glow + light/dark switch, with [child]
/// centered and scrollable. Pass [onBack] to show a back arrow (top-left).
class OrganizerAuthPage extends StatelessWidget {
  const OrganizerAuthPage({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.onBack,
  });

  final Widget child;
  final double maxWidth;
  final VoidCallback? onBack;

  static const double _padTop = 72;
  static const double _padBottom = 40;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          const TopGlowBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minHeight = (constraints.maxHeight - _padTop - _padBottom)
                    .clamp(0.0, double.infinity)
                    .toDouble();
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    _padTop,
                    24,
                    _padBottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ThemeModeSwitch(),
              ),
            ),
          ),
          if (onBack != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The rounded surface card used by every centered screen.
class OrganizerCard extends StatelessWidget {
  const OrganizerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(32),
    this.radius = 28,
    this.borderColor,
    this.borderWidth = 1,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? p.border, width: borderWidth),
        boxShadow: p.isDark
            ? null
            : [
                BoxShadow(
                  color: p.primary.withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Round icon badge (e.g. the green tick on "You're approved").
class OrganizerStatusIcon extends StatelessWidget {
  const OrganizerStatusIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 72,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.44),
    );
  }
}

/// Purple gradient call-to-action, 49px tall, 14px corners.
class OrganizerPrimaryButton extends StatelessWidget {
  const OrganizerPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 49,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: p.primary.withValues(alpha: p.isDark ? 0.40 : 0.32),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              gradient: FairTixPalette.buttonGradient,
              borderRadius: radius,
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? onPressed : null,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: orgText(
                          p,
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
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

/// Outlined secondary button (surface fill, hairline border).
class OrganizerSecondaryButton extends StatelessWidget {
  const OrganizerSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 49,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);

    return Material(
      color: p.surface,
      borderRadius: radius,
      child: Ink(
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: p.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: orgText(p, size: 14, weight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small purple text link ("Log in", "Change plan", ...).
class OrganizerTextLink extends StatelessWidget {
  const OrganizerTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.size = 13,
  });

  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: orgText(
            p,
            size: size,
            weight: FontWeight.w700,
            color: p.accentLabel,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

/// Bold 13px field label.
class OrganizerFieldLabel extends StatelessWidget {
  const OrganizerFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Text(
      text,
      style: orgText(p, size: 13, weight: FontWeight.w600, height: 1.3),
    );
  }
}

/// Rounded text input, 54px tall, on the surface color.
class OrganizerTextField extends StatelessWidget {
  const OrganizerTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// Optional trailing widget inside the field (e.g. a show/hide eye).
  final Widget? suffix;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final style = orgText(p, size: 14, height: 1.3);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      style: style,
      cursorColor: p.accentLabel,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: style.copyWith(color: p.textSecondary),
        errorStyle: orgText(p, size: 12, color: p.danger),
        suffixIcon: suffix,
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: _border(p.border),
        enabledBorder: _border(p.border),
        focusedBorder: _border(p.accentLabel),
        errorBorder: _border(p.danger),
        focusedErrorBorder: _border(p.danger),
      ),
    );
  }
}

/// Label above an [OrganizerTextField].
class OrganizerLabeledField extends StatelessWidget {
  const OrganizerLabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrganizerFieldLabel(label),
        const SizedBox(height: 7.5),
        OrganizerTextField(
          controller: controller,
          hint: hint,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}

/// Dashed, purple-tinted drop zone used for document uploads.
class OrganizerUploadBox extends StatelessWidget {
  const OrganizerUploadBox({
    super.key,
    required this.title,
    required this.hint,
    required this.onTap,
    this.fileName,
  });

  final String title;
  final String hint;
  final VoidCallback onTap;

  /// When set, the box shows the picked file instead of the prompt.
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final picked = fileName != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: p.accentLabel.withValues(alpha: 0.7),
            radius: 16,
          ),
          child: Container(
            height: 92,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: p.isDark ? 0.24 : 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  picked ? Icons.check_circle_rounded : Icons.file_upload_outlined,
                  size: 20,
                  color: p.accentLabel,
                ),
                const SizedBox(height: 4),
                Text(
                  picked ? fileName! : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: orgText(
                    p,
                    size: 14,
                    weight: FontWeight.w700,
                    color: p.accentLabel,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  picked ? 'Tap to replace' : hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: orgText(
                    p,
                    size: 12,
                    color: p.textSecondary,
                    height: 1.3,
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
