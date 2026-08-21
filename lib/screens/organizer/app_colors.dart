import 'package:flutter/material.dart';

/// Formats a [DateTime] as e.g. "Jul 25, 2026" for display across the
/// organizer screens (profile, subscription, etc.) without pulling in the
/// `intl` package for a single use case.
String formatFriendlyDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Centralized color palette & shared styles for FairTix Organizer app.
class AppColors {
  AppColors._();

  // Core purple brand colors
  static const Color primaryPurple = Color(0xFF7C3AED); // violet-600
  static const Color primaryPurpleDark = Color(0xFF5B21B6); // violet-800
  static const Color primaryPurpleDarker = Color(0xFF4C1D95); // violet-900
  static const Color primaryPurpleLight = Color(0xFF8B5CF6); // violet-500
  static const Color sidebarActive = Color(0xFF6D28D9); // violet-700

  // Gradient used on splash/auth screens
  static const List<Color> authGradient = [
    Color(0xFF4C1D95),
    Color(0xFF7C3AED),
  ];

  // Neutral / background
  static const Color pageBackground = Color(0xFFF4F2FB);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Text
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGray = Color(0xFF6B7280);
  static const Color textLightPurple = Color(0xFFDDD6FE);

  // Status colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color successGreenBg = Color(0xFFD1FAE5);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color dangerRedBg = Color(0xFFFEE2E2);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color warningOrangeBg = Color(0xFFFEF3C7);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color infoBlueBg = Color(0xFFDBEAFE);

  static const Color darkNavy = Color(0xFF1E1B3A);
}

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Poppins';

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
  );

  static const TextStyle bodyGray = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}

/// Reusable primary (filled) button matching the purple CTA style.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double height;
  final bool isGradient;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primaryPurple,
    this.textColor = Colors.white,
    this.height = 52,
    this.isGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isGradient ? null : color,
        gradient: isGradient
            ? const LinearGradient(
                colors: [
                  AppColors.primaryPurpleDark,
                  AppColors.primaryPurple,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.button.copyWith(color: textColor),
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

/// Reusable outline (border only) button.
class OutlineButtonWidget extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color textColor;
  final double height;

  const OutlineButtonWidget({
    super.key,
    required this.label,
    required this.onPressed,
    this.borderColor = AppColors.primaryPurple,
    this.textColor = AppColors.primaryPurple,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(color: textColor),
        ),
      ),
    );
  }
}

/// Reusable text input field matching the design's rounded-rectangle inputs.
class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscureText;
  final TextEditingController? controller;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.controller,
    this.prefixIcon,
    this.keyboardType,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyGray,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryPurple),
            ),
          ),
        ),
      ],
    );
  }
}

/// Left decorative purple gradient panel shared by splash-style auth screens.
class AuthSidePanel extends StatelessWidget {
  final Widget child;

  const AuthSidePanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.authGradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            child: _circle(180, Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            top: 40,
            right: -60,
            child: _circle(220, Colors.white.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _circle(240, Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            bottom: 60,
            right: -40,
            child: _circle(200, Colors.white.withOpacity(0.10)),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// The FairTix wordmark logo used repeatedly (white on purple, or purple on white).
class FairTixLogo extends StatelessWidget {
  final Color textColor;
  final double fontSize;
  final bool showBadge;

  const FairTixLogo({
    super.key,
    this.textColor = Colors.white,
    this.fontSize = 24,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge) {
      return Text(
        'FairTix',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            'F',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'FairTix',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }
}