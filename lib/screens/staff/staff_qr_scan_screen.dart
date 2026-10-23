import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/scanner_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import '../../widgets/top_glow_background.dart';
import 'staff_pin_entry_screen.dart';

/// Live QR scanning screen for entry staff (Mahilum "QR Scanner" designs).
/// Validated via [ScannerAccess] (see StaffPinEntryScreen), so no FairTix
/// login is needed here either. Every detected QR is sent to `scan_ticket`
/// (see supabase/scanner_functions.sql), which is also where the ticket
/// actually gets invalidated (flipped to used) the moment it's accepted.
///
/// After each scan the result card stays on screen and the camera is paused
/// until staff tap "Scan Next", so a result can't be missed at a busy door.
class StaffQrScanScreen extends StatefulWidget {
  const StaffQrScanScreen({super.key, required this.access});

  final ScannerAccess access;

  @override
  State<StaffQrScanScreen> createState() => _StaffQrScanScreenState();
}

class _StaffQrScanScreenState extends State<StaffQrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _isProcessing = false;
  ScanOutcome? _outcome;
  int _acceptedCount = 0;
  int _rejectedCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing || _outcome != null) return;
    final code =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final outcome = await ScannerRepository.instance
          .scanTicket(access: widget.access, qrToken: code);
      if (!mounted) return;
      if (outcome.isAccepted) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
      setState(() {
        _outcome = outcome;
        if (outcome.isAccepted) {
          _acceptedCount++;
        } else {
          _rejectedCount++;
        }
      });
    } on ScannerRepositoryException catch (e) {
      if (!mounted) return;
      if (e.isSessionEnded) {
        // The organizer ended the session (or it expired). This is not a bad
        // ticket, so it is not counted as a rejection.
        await _handleSessionEnded();
        return;
      }
      // Could not reach the server: the ticket was never judged, so show a
      // "try again" notice and leave the counters alone.
      setState(() {
        _outcome = ScanOutcome(result: ScanResult.error, message: e.message);
      });
    }
  }

  void _scanNext() {
    setState(() {
      _outcome = null;
      _isProcessing = false;
    });
  }

  Future<void> _handleSessionEnded() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Session ended'),
        content: const Text(
          'The organizer ended this scanner session, or it has expired. '
          'Enter a new PIN to keep scanning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const StaffPinEntryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final outcome = _outcome;
    final _Verdict? verdict = outcome == null ? null : _Verdict.of(p, outcome);

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          const TopGlowBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(title: widget.access.eventTitle),
                            const SizedBox(height: 18),
                            _CameraFrame(
                              controller: _controller,
                              onDetect: _handleDetect,
                              bracketColor: verdict?.color ?? p.accentLabel,
                            ),
                            const SizedBox(height: 18),
                            if (verdict != null)
                              _ResultCard(verdict: verdict)
                            else
                              _IdleHint(
                                accepted: _acceptedCount,
                                rejected: _rejectedCount,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (verdict != null) _ScanNextBar(onPressed: _scanNext),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the result card shows for one scan.
class _Verdict {
  const _Verdict({
    required this.title,
    required this.subtitle,
    required this.note,
    required this.icon,
    required this.color,
    required this.card,
    required this.badge,
    required this.border,
  });

  final String title;
  final String subtitle;
  final String note;
  final IconData icon;
  final Color color;
  final Color card;
  final Color badge;
  final Color border;

  factory _Verdict.of(FairTixPalette p, ScanOutcome o) {
    switch (o.result) {
      case ScanResult.valid:
        return _Verdict(
          title: 'Valid ticket',
          subtitle: '${o.tierName ?? 'Ticket'} · 1 person',
          note: 'Entry allowed.',
          icon: Icons.check_rounded,
          color: p.success,
          card: p.successCard,
          badge: p.successIcon,
          border: p.success,
        );
      case ScanResult.error:
        return _Verdict(
          title: 'Could not scan',
          subtitle: o.message ?? 'Something went wrong.',
          note: 'Scan the ticket again.',
          icon: Icons.priority_high_rounded,
          color: p.warning,
          card: p.warningSurface,
          badge: p.warningBorder,
          border: p.warning,
        );
      case ScanResult.alreadyUsed:
      case ScanResult.wrongEvent:
      case ScanResult.invalid:
        return _Verdict(
          title: 'Ticket rejected',
          subtitle: switch (o.result) {
            ScanResult.alreadyUsed => 'Already used',
            ScanResult.wrongEvent => 'Wrong event',
            _ => 'Invalid QR code',
          },
          note: 'Do not allow entry.',
          icon: Icons.close_rounded,
          color: p.danger,
          card: p.dangerCard,
          badge: p.dangerIcon,
          border: p.danger,
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCANNER SESSION',
                style: orgText(
                  p,
                  size: 12,
                  weight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: p.accentLabel,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: orgText(
                  p,
                  size: 26,
                  weight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Leave scanner',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.close_rounded, color: p.textSecondary),
        ),
      ],
    );
  }
}

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({
    required this.controller,
    required this.onDetect,
    required this.bracketColor,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final Color bracketColor;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return AspectRatio(
      aspectRatio: 7 / 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(
          color: p.cameraSurface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(controller: controller, onDetect: onDetect),
              CustomPaint(painter: _BracketPainter(color: bracketColor)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four rounded corner brackets, inset from the frame edge.
class _BracketPainter extends CustomPainter {
  const _BracketPainter({required this.color});

  final Color color;

  static const double _inset = 50;
  static const double _length = 58;
  static const double _radius = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final corner = Path()
      ..moveTo(_inset, _inset + _length)
      ..lineTo(_inset, _inset + _radius)
      ..arcToPoint(
        const Offset(_inset + _radius, _inset),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(_inset + _length, _inset);

    for (final flipX in [false, true]) {
      for (final flipY in [false, true]) {
        canvas.save();
        canvas.translate(flipX ? size.width : 0, flipY ? size.height : 0);
        canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
        canvas.drawPath(corner, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.verdict});

  final _Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: verdict.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: verdict.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: verdict.badge,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(verdict.icon, color: verdict.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verdict.title,
                        style: orgText(
                          p,
                          size: 20,
                          weight: FontWeight.w800,
                          color: verdict.color,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        verdict.subtitle,
                        style: orgText(
                          p,
                          size: 14,
                          color: p.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              verdict.note,
              style: orgText(p, size: 14, color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.accepted, required this.rejected});

  final int accepted;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    Widget chip(IconData icon, Color color, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(text, style: orgText(p, size: 13, weight: FontWeight.w700)),
            ],
          ),
        );

    return Column(
      children: [
        Text(
          'Point the camera at the ticket’s QR code.',
          textAlign: TextAlign.center,
          style: orgText(p, size: 14, color: p.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            chip(Icons.check_circle_rounded, p.success, '$accepted accepted'),
            chip(Icons.cancel_rounded, p.danger, '$rejected rejected'),
          ],
        ),
      ],
    );
  }
}

class _ScanNextBar extends StatelessWidget {
  const _ScanNextBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(999);

    return Container(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: p.primary.withValues(alpha: p.isDark ? 0.40 : 0.32),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: Ink(
                height: 54,
                decoration: BoxDecoration(
                  gradient: FairTixPalette.buttonGradient,
                  borderRadius: radius,
                ),
                child: InkWell(
                  borderRadius: radius,
                  onTap: onPressed,
                  child: Center(
                    child: Text(
                      'Scan Next',
                      style: orgText(
                        p,
                        size: 17,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
