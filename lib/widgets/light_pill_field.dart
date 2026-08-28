import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pill-shaped input field for light-background screens (Registration).
class LightPillField extends StatelessWidget {
  const LightPillField({
    super.key,
    this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.prefixWidget,
    this.suffixWidget,
    this.obscureText = false,
    this.errorText,
    this.textInputAction,
  });

  final String? label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final Widget? prefixWidget;
  final Widget? suffixWidget;
  final bool obscureText;
  /// Optional validation message shown in red beneath the field.
  final String? errorText;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.fieldLabelLight),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputFillLight,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: errorText != null ? AppColors.error : AppColors.inputBorderLight,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            textInputAction: textInputAction,
            style: AppTextStyles.fieldInputLight,
            cursorColor: AppColors.accentPurple,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyles.fieldInputLight.copyWith(color: AppColors.textMuted),
              prefixIcon: prefixWidget,
              suffixIcon: suffixWidget,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pill-shaped dropdown for light-background screens (Birthday, ID Type).
class LightPillDropdown<T> extends StatelessWidget {
  const LightPillDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.fieldLabelLight),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.inputFillLight,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.inputBorderLight, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
              style: AppTextStyles.fieldInputLight,
            ),
          ),
        ),
      ],
    );
  }
}
