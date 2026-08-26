import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/ticket.dart';
import '../theme/app_theme.dart';

/// Card for the "My Listed Tickets" section of the Resale Market — one of
/// the current user's own tickets that's currently listed for resale.
class MyListingCard extends StatelessWidget {
  const MyListingCard({super.key, required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _formatCloseDate(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_months[dt.month - 1]} ${dt.day}, $hour12$period';
  }

  @override
  Widget build(BuildContext context) {
    final price = ticket.resalePrice ?? ticket.tier.price;
    final closesAt = ticket.event.resaleListingCloseTime;
    final hoursLeft = closesAt.difference(DateTime.now()).inHours;
    final isClosingSoon = hoursLeft <= 24;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentPurple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.accentPurple, shape: BoxShape.circle),
              child: const Icon(Icons.confirmation_number_rounded, color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ticket.tier.name} \u2022 ${ticket.event.dateLabel.split(' \u2022 ').first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Closes ${_formatCloseDate(closesAt)}',
                    maxLines: 1,
                    style: AppTextStyles.bodyMuted.copyWith(
                      fontSize: 11,
                      color: isClosingSoon ? AppColors.warning : AppColors.textMuted,
                      fontWeight: isClosingSoon ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPeso(price).replaceAll('.00', ''),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accentPurple),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isClosingSoon ? AppColors.warning : AppColors.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isClosingSoon ? 'Closing Soon' : 'Live',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
