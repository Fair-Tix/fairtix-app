import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown on My Tickets and the ticket screen when the data on screen is
/// the saved offline copy rather than a live fetch (see
/// TicketRepository.isFromCache). Tells the user the QR codes are still
/// valid to show, but statuses may be out of date.
class OfflineCopyBanner extends StatelessWidget {
  const OfflineCopyBanner({super.key, this.lastSyncedAt});

  final DateTime? lastSyncedAt;

  static const Color _amber = Color(0xFFD97706);

  static String _format(DateTime t) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = t.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final synced = lastSyncedAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: _amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              synced == null
                  ? 'You\u2019re offline. Showing your saved tickets; statuses may be out of date.'
                  : 'You\u2019re offline. Showing tickets saved ${_format(synced)}; statuses may be out of date.',
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 12.5, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
