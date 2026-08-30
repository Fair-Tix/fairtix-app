import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded filter chip used in the Resale Market's category row
/// (All / Concerts / Sports / Theater).
class ResaleFilterChip extends StatelessWidget {
  const ResaleFilterChip({super.key, required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentPurple : AppColors.inputFillLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.accentPurple : AppColors.inputBorderLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
