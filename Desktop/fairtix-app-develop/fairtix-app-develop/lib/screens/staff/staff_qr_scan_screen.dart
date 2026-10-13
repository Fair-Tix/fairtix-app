import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/scanner_repository.dart';
import '../../theme/app_theme.dart';

/// Live QR scanning screen for entry staff. Validated via
/// [ScannerAccess] (see StaffPinEntryScreen), so no FairTix login is
/// needed here either. Every detected QR is sent to `scan_ticket` (see
/// supabase/scanner_functions.sql), which is also where the ticket
/// actually gets invalidated (flipped to used) the moment it's accepted.
class StaffQrScanScreen extends StatefulWidget {
  const StaffQrScanScreen({super.key, required this.access});

  final ScannerAccess access;

  @override
  State<StaffQrScanScreen> createState() => _StaffQrScanScreenState();
}

class _StaffQrScanScreenState extends State<StaffQrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _isProcessing = false;
  ScanOutcome? _lastOutcome;
  int _acceptedCount = 0;
  int _rejectedCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final outcome = await ScannerRepository.instance.scanTicket(access: widget.access, qrToken: code);
      if (!mounted) return;
      setState(() {
        _lastOutcome = outcome;
        if (outcome.isAccepted) {
          _acceptedCount++;
        } else {
          _rejectedCount++;
        }
      });
    } on ScannerRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _lastOutcome = ScanOutcome(result: ScanResult.invalid, eventTitle: null, tierName: e.message);
        _rejectedCount++;
      });
    }

    // Briefly hold the Accepted/Rejected overlay, then resume scanning.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _lastOutcome = null;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          // Dimmed frame overlay so staff know where to aim.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      widget.access.eventTitle,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 48), // balances the close button
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    const SizedBox(width: 6),
                    Text('$_acceptedCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 18),
                    const Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 6),
                    Text('$_rejectedCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          if (_lastOutcome != null) _ResultOverlay(outcome: _lastOutcome!),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.outcome});

  final ScanOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final isAccepted = outcome.isAccepted;
    final color = isAccepted ? AppColors.success : AppColors.error;

    return Container(
      color: color.withValues(alpha: 0.92),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: Colors.white,
            size: 96,
          ),
          const SizedBox(height: 18),
          Text(
            outcome.headline,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          if (outcome.tierName != null) ...[
            const SizedBox(height: 8),
            Text(
              outcome.tierName!,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
