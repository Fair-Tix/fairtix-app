import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_resale_ui.dart';
import '../../widgets/ft_transaction_ui.dart' show formatPesoShort;
import 'transactions_screen.dart';

/// Seller-side confirmation shown when tapping a "your ticket has been
/// bought" notification — confirms the resale completed and shows what the
/// seller receives after FairTix's flat resale fee.
class TicketSoldScreen extends StatelessWidget {
  const TicketSoldScreen({
    super.key,
    required this.ticket,
    required this.buyerName,
    required this.salePrice,
  });

  final Ticket ticket;
  final String buyerName;

  /// What the buyer paid (the listing price), before FairTix's fee.
  final double salePrice;

  void _handleViewTransactions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    final fee = (salePrice * kResaleSellerFeeRate * 100).round() / 100;
    final receive = salePrice - fee;

    return FtResultScaffold(
      icon: Icons.check_rounded,
      title: 'Your ticket sold',
      primaryLabel: 'Done',
      onPrimary: () => Navigator.of(context).maybePop(),
      secondaryLabel: 'View transactions',
      onSecondary: () => _handleViewTransactions(context),
      body: [
        Center(
          child: Text(
            'You receive',
            style: GoogleFonts.plusJakartaSans(fontSize: 17, color: t.subtitleColor),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            formatPesoShort(receive),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 60,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: t.success,
            ),
          ),
        ),
        const SizedBox(height: 24),
        FtSurfaceCard(
          radius: 26,
          child: Column(
            children: [
              FtSummaryRow(label: 'Listing price', value: formatPesoShort(salePrice)),
              const SizedBox(height: 14),
              FtSummaryRow(
                label: 'Resale fee (${(kResaleSellerFeeRate * 100).round()}%)',
                value: '−${formatPesoShort(fee)}',
              ),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: t.divider),
              const SizedBox(height: 16),
              FtSummaryRow(label: 'You receive', value: formatPesoShort(receive), strong: true),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FtNote(
          icon: Icons.verified_user_outlined,
          text: 'Sold to a verified buyer. Funds release once their QR is issued.',
        ),
      ],
    );
  }
}
