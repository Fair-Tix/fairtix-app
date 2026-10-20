import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../services/access_control.dart';
import '../../services/resale_repository.dart';
import '../../services/screen_protection.dart';
import '../../services/ticket_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashed_divider.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/offline_copy_banner.dart';
import '../../widgets/purple_header_bar.dart';
import 'resale_listing_screen.dart';

/// "My Ticket" screen — shown after tapping a ticket from the My Tickets
/// list. Displays the ticket's details and QR code, and is the entry
/// point into the in-app resale flow.
///
/// Screenshots and screen recording are blocked while this screen is open
/// (see [ScreenProtection]) so the QR code can't be copied.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticket});

  final Ticket ticket;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  Ticket get ticket => widget.ticket;

  /// The QR is only shown while the ticket can still get someone in: valid,
  /// or listed for resale (still the owner's until someone buys it). A used
  /// or canceled ticket is rejected at the door anyway, so showing a
  /// scannable code for it would only confuse the holder and the staff.
  bool get _isQrActive => ticket.status == TicketStatus.valid || ticket.status == TicketStatus.listed;

  bool _isCancelingListing = false;

  @override
  void initState() {
    super.initState();
    ScreenProtection.enable();
  }

  @override
  void dispose() {
    ScreenProtection.disable();
    super.dispose();
  }

  Future<void> _handleListForResale(BuildContext context) async {
    // Reselling needs an admin-approved account; otherwise explain why it's
    // locked (the database refuses the listing as well).
    if (!await ensureBuyerApproved(context)) return;
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResaleListingScreen(ticket: ticket)),
    );
  }

  Future<void> _handleCancelListing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this listing?'),
        content: const Text(
          'Your ticket will come off the Resale Market and go back to being a regular ticket in your wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Listing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel Listing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelingListing = true);
    try {
      await ResaleRepository.instance.cancelListing(ticketId: ticket.id);
    } on ResaleException catch (e) {
      if (!mounted) return;
      setState(() => _isCancelingListing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
      return;
    }

    // The cancel worked. Reload the wallet so the status is right when we
    // go back; if the reload fails the next load will catch up.
    try {
      await TicketRepository.instance.refresh();
    } on TicketRepositoryException {
      // Ignored on purpose; see above.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listing canceled. Your ticket is valid again.')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final event = ticket.event;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'My Ticket',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (TicketRepository.instance.isFromCache) ...[
              OfflineCopyBanner(lastSyncedAt: TicketRepository.instance.lastSyncedAt),
              const SizedBox(height: 14),
            ],
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.25),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.accentPurple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.dateLabel.split(' \u2022 ').first,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 15, color: AppColors.accentPurple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ticket.tier.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ticket.tier.seatingLabel,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentPurple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 17, color: AppColors.accentPurple),
                      const SizedBox(width: 8),
                      Text(
                        ticket.ownerName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const DashedDivider(),
                  const SizedBox(height: 24),
                  if (_isQrActive) ...[
                    const Center(
                      child: Text(
                        'SCAN TO ENTER',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.accentPurple, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: _TicketQrCode(qrToken: ticket.qrToken, size: 200),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text(
                        'This QR code is unique to your account. Do not share.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMuted,
                      ),
                    ),
                  ] else
                    _InactiveQrNotice(status: ticket.status),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    switch (ticket.status) {
      case TicketStatus.valid:
        return GradientPillButton(
          label: 'List for Resale',
          onPressed: () => _handleListForResale(context),
        );
      case TicketStatus.listed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientPillButton(
              label: 'Listed for Resale \u2014 ${formatPeso(ticket.resalePrice ?? ticket.tier.price)}',
              onPressed: null,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isCancelingListing ? null : _handleCancelListing,
              child: Text(
                _isCancelingListing ? 'Canceling\u2026' : 'Cancel Listing',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentPurple),
              ),
            ),
          ],
        );
      case TicketStatus.used:
        return const GradientPillButton(
          label: 'Ticket Already Used',
          onPressed: null,
        );
      case TicketStatus.canceled:
        return const GradientPillButton(
          label: 'Ticket Canceled',
          onPressed: null,
        );
    }
  }
}

/// Shown in place of the QR code when the ticket is used or canceled.
class _InactiveQrNotice extends StatelessWidget {
  const _InactiveQrNotice({required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final isUsed = status == TicketStatus.used;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.inputFillLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorderLight),
      ),
      child: Column(
        children: [
          Icon(
            isUsed ? Icons.check_circle_outline_rounded : Icons.block_rounded,
            size: 44,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'QR code no longer active',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            isUsed
                ? 'This ticket was already scanned at the event entrance.'
                : 'This ticket was canceled, so it can no longer be used to enter.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

/// Renders [qrToken] (the ticket's real `qr_code_token` from
/// `public.tickets`) as a scannable QR code via `qr_flutter`.
///
/// The QR image is drawn locally from the token, so it needs no network.
/// What makes it viewable offline (including after an app restart) is
/// that the token itself is saved to encrypted device storage by
/// TicketRepository / TicketCache, not anything in this widget.
class _TicketQrCode extends StatelessWidget {
  const _TicketQrCode({required this.qrToken, required this.size});

  final String qrToken;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorderLight),
      ),
      child: QrImageView(
        data: qrToken,
        version: QrVersions.auto,
        size: size,
        backgroundColor: AppColors.white,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.textDark),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.textDark),
      ),
    );
  }
}
