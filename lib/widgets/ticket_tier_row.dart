import 'package:flutter/material.dart';

import '../models/event.dart';
import '../theme/app_theme.dart';

/// Selectable ticket tier row on the Event Details screen
/// (VIP, Gold, Silver, Bronze, Balcony).
class TicketTierRow extends StatelessWidget {
  const TicketTierRow({
    super.key,
    required this.tier,
    required this.isSelected,
    required this.onTap,
  });

  final TicketTier tier;
  final bool isSelected;

  /// Null when tier selection is disabled (e.g. the purchase limit for
  /// this event has been reached) — the row is dimmed and unresponsive.
  final VoidCallback? onTap;

  bool get _isDisabled => onTap == null;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isDisabled ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentPurple.withValues(alpha: 0.08) : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.accentPurple : AppColors.inputBorderLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tier.name} (${tier.seatingLabel})',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                ],
              ),
              Text(
                formatPeso(withPlatformFee(tier.price, kPrimaryPlatformFeeRate)).replaceAll('.00', ''),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accentPurple),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
