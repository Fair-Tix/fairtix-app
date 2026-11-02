import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../services/access_control.dart';
import '../../services/resale_repository.dart';
import '../../services/screen_protection.dart';
import '../../services/ticket_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtBackButton;
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import '../../widgets/offline_copy_banner.dart';
import 'resale_listing_screen.dart';

/// "My Ticket" screen — shown after tapping a ticket from the My Tickets
/// list. Displays the ticket's details and QR code, and is the entry
/// point into the in-app resale flow. Follows the Light / Dark switch.
///
/// Screenshots and screen recording are blocked while this screen is open
/// (see [ScreenProtection]) so the QR code can't be copied.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticket});

  final Ticket ticket;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  static const int _entranceMs = 650;

  Ticket get ticket => widget.ticket;

  /// The QR is only shown while the ticket can still get someone in: valid,
  /// or listed for resale (still the owner's until someone buys it). A used
  /// or canceled ticket is rejected at the door anyway, so showing a
  /// scannable code for it would only confuse the holder and the staff.
  bool get _isQrActive => ticket.status == TicketStatus.valid || ticket.status == TicketStatus.listed;

  bool _isCancelingListing = false;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _entranceMs),
  );
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    ScreenProtection.enable();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
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
    // The dialog is its own route, outside the screen's theme scope, so it
    // reads the Light / Dark switch directly.
    final t = FtAuthTheme.live(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surfaceFill,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: t.surfaceBorder),
        ),
        title: Text(
          'Cancel this listing?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: t.titleColor,
          ),
        ),
        content: Text(
          'Your ticket will come off the Resale Market and go back to being a regular ticket in your wallet.',
          style: t.subtitle().copyWith(color: t.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep Listing', style: t.link()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cancel Listing',
              style: t.link().copyWith(color: t.danger),
            ),
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

  ({String label, Color color}) _statusBadge(FtAuthTheme t) => switch (ticket.status) {
        TicketStatus.valid => (label: 'Valid', color: t.success),
        TicketStatus.listed => (label: 'Listed', color: t.activeAccent),
        TicketStatus.used => (label: 'Used', color: t.secondaryText),
        TicketStatus.canceled => (label: 'Canceled', color: t.danger),
      };

  @override
  Widget build(BuildContext context) {
    final event = ticket.event;
    final t = FtAuthTheme.live(context);
    final badge = _statusBadge(t);

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.overlayStyle,
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: FtAuthBackground(
          theme: t,
          child: SafeArea(
            child: Column(
              children: [
                FtReveal(
                  animation: _entrance,
                  startMs: 0,
                  endMs: 300,
                  totalMs: _entranceMs,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: Row(
                      children: [
                        FtBackButton(onTap: () => Navigator.of(context).maybePop()),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'My Ticket',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: t.titleColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (TicketRepository.instance.isFromCache) ...[
                          OfflineCopyBanner(
                            dark: t.isDark,
                            lastSyncedAt: TicketRepository.instance.lastSyncedAt,
                          ),
                          const SizedBox(height: 14),
                        ],
                        FtReveal(
                          animation: _entrance,
                          startMs: 80,
                          endMs: 480,
                          totalMs: _entranceMs,
                          slide: 16,
                          child: _buildCard(event, badge, t),
                        ),
                      ],
                    ),
                  ),
                ),
                FtReveal(
                  animation: _entrance,
                  startMs: 200,
                  endMs: 600,
                  totalMs: _entranceMs,
                  slide: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.bgBottom,
                      border: Border(top: BorderSide(color: t.surfaceBorder)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                      child: _buildAction(context, t),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildCard(
    EventSummary event,
    ({String label, Color color}) badge,
    FtAuthTheme t,
  ) {
    return Semantics(
      container: true,
      label: '${event.title}, ${ticket.tier.name} ticket for ${ticket.ownerName}, '
          '${event.dateLabel.split(' \u2022 ').first}, ${event.venue}. ${badge.label}',
      child: Container(
        decoration: BoxDecoration(
          color: t.isDark ? t.surfaceFill.withValues(alpha: 0.8) : t.surfaceFill,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: t.surfaceBorder),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    constraints: const BoxConstraints(maxWidth: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [FtColors.progressStart, FtColors.otpButtonEnd],
                      ),
                    ),
                    child: Text(
                      ticket.tier.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FtText.title().copyWith(
                      fontSize: 32,
                      letterSpacing: -0.5,
                      color: t.titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${event.dateLabel.split(' \u2022 ').first} \u2022 ${event.venue}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      height: 1.35,
                      color: t.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_isQrActive) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // QR fills the card width, minus its white frame.
                        final qrSize = (constraints.maxWidth - 28).clamp(160.0, 260.0);
                        return _TicketQrCode(qrToken: ticket.qrToken, size: qrSize);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unique to your account. Do not share.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.3,
                        color: t.secondaryText,
                      ),
                    ),
                  ] else
                    _InactiveQrNotice(status: ticket.status),
                  const SizedBox(height: 22),
                ],
              ),
            ),
            // Perforation: dashed line with a notch at each card edge.
            SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: CustomPaint(painter: _DashPainter(t.surfaceBorder)),
                    ),
                  ),
                  Positioned(left: -11, top: 0, child: _notch(t)),
                  Positioned(right: -11, top: 0, child: _notch(t)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: badge.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: badge.color),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          badge.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: badge.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Screen protection is switched on for the whole screen
                  // (initState), so this simply says so while a QR is shown.
                  if (_isQrActive) ...[
                    Icon(Icons.lock_outline_rounded, size: 16, color: t.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      'Screenshots blocked',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.2,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notch(FtAuthTheme t) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.bgBottom,
          border: Border.all(color: t.surfaceBorder),
        ),
      );

  Widget _buildAction(BuildContext context, FtAuthTheme t) {
    switch (ticket.status) {
      case TicketStatus.valid:
        return FtGradientButton(
          label: 'List for Resale',
          onPressed: () => _handleListForResale(context),
        );
      case TicketStatus.listed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FtGradientButton(
              label: 'Listed for Resale \u2014 ${formatPeso(ticket.resalePrice ?? ticket.tier.price)}',
              onPressed: null,
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _isCancelingListing ? null : _handleCancelListing,
              child: Text(
                _isCancelingListing ? 'Canceling\u2026' : 'Cancel Listing',
                style: t.link().copyWith(fontSize: 14.5),
              ),
            ),
          ],
        );
      case TicketStatus.used:
        return const FtGradientButton(label: 'Ticket Already Used', onPressed: null);
      case TicketStatus.canceled:
        return const FtGradientButton(label: 'Ticket Canceled', onPressed: null);
    }
  }
}

/// Dashed perforation line between the two card notches.
class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0, size.width).toDouble(), y), paint);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Shown in place of the QR code when the ticket is used or canceled.
class _InactiveQrNotice extends StatelessWidget {
  const _InactiveQrNotice({required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final isUsed = status == TicketStatus.used;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: t.isDark ? t.bgBottom.withValues(alpha: 0.5) : t.bgBottom,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Column(
        children: [
          Icon(
            isUsed ? Icons.check_circle_outline_rounded : Icons.block_rounded,
            size: 44,
            color: t.secondaryText,
          ),
          const SizedBox(height: 12),
          Text(
            'QR code no longer active',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: t.titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isUsed
                ? 'This ticket was already scanned at the event entrance.'
                : 'This ticket was canceled, so it can no longer be used to enter.',
            textAlign: TextAlign.center,
            style: t.subtitle().copyWith(color: t.secondaryText),
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
///
/// Kept dark-on-white with a quiet margin so scanners read it reliably.
class _TicketQrCode extends StatelessWidget {
  const _TicketQrCode({required this.qrToken, required this.size});

  final String qrToken;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Semantics(
      label: 'Ticket QR code',
      image: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          // On Light the white frame sits on a white card, so it gets a hairline.
          border: t.isDark ? null : Border.all(color: t.surfaceBorder),
        ),
        child: QrImageView(
          data: qrToken,
          version: QrVersions.auto,
          size: size,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: FtColors.bgBottom),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: FtColors.bgBottom,
          ),
        ),
      ),
    );
  }
}
