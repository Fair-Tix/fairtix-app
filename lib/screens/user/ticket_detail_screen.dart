import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashed_divider.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/purple_header_bar.dart';
import 'resale_listing_screen.dart';

/// "My Ticket" screen — shown after tapping a ticket from the My Tickets
/// list. Displays the ticket's details and QR code, and is the entry
/// point into the in-app resale flow.
class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({super.key, required this.ticket});

  final Ticket ticket;

  void _handleListForResale(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResaleListingScreen(ticket: ticket)),
    );
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
        return GradientPillButton(
          label: 'Listed for Resale \u2014 ${formatPeso(ticket.resalePrice ?? ticket.tier.price)}',
          onPressed: null,
        );
      case TicketStatus.used:
        return const GradientPillButton(
          label: 'Ticket Already Used',
          onPressed: null,
        );
    }
  }
}

/// Renders [qrToken] (the ticket's real `qr_code_token` from
/// `public.tickets`) as a scannable QR code via `qr_flutter`, and keeps
/// the rendered widget for a given token cached in memory for the
/// lifetime of the app run — reopening the same ticket's detail screen
/// doesn't regenerate the QR image from scratch. This is in-memory
/// caching only (cleared on app restart); persisting it to disk would
/// need a local storage package that isn't in this project's
/// dependencies yet.
class _TicketQrCode extends StatelessWidget {
  const _TicketQrCode({required this.qrToken, required this.size});

  final String qrToken;
  final double size;

  static final Map<String, Widget> _cache = {};

  @override
  Widget build(BuildContext context) {
    return _cache.putIfAbsent(
      qrToken,
      () => Container(
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
      ),
    );
  }
}
