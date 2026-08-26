import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pill-shaped input field with a translucent fill, matching the
/// Username/Password fields in the Figma login design.
class PillTextField extends StatelessWidget {
  const PillTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.fieldBorder, width: 1),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: AppTextStyles.fieldInput,
            cursorColor: AppColors.white,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyles.fieldInput.copyWith(color: AppColors.faintWhite),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: AppColors.subtleWhite, size: 20)
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
      ],
    );
  }
}
