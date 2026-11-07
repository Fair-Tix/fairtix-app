import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';

/// Error modal shown when a PayMongo payment fails or is canceled and the
/// buyer lands back in the app. No ticket was issued and nobody was charged,
/// so the only action is to close it and try again. Pass a [context] that is
/// below the screen's [FtAuthThemeScope] so the dialog matches Light / Dark.
Future<void> showPaymentFailedDialog(BuildContext context, {bool canceled = false}) {
  final t = FtAuthTheme.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: t.cardFill,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 30, color: t.danger),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                canceled ? 'Payment canceled' : 'Payment failed',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: t.titleColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canceled
                  ? 'The payment was not completed. You have not been charged and no ticket was issued.'
                  : 'Your payment did not go through. You have not been charged and no ticket was issued. You can try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.45,
                color: t.subtitleColor,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FtGradientButton(
                label: 'Try again',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
