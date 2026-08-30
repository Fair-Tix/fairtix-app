import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../navigation/app_nav.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pill_button.dart';
import 'ticket_detail_screen.dart';

class CheckoutConfirmationScreen extends StatelessWidget {
  const CheckoutConfirmationScreen({
    super.key,
    required this.event,
    required this.tier,
    this.buyerEmail,
    this.purchasedTicket,
  });

  final EventSummary event;
  final TicketTier tier;

  /// Defaults to the signed-in user's email (see [UserSession]) when not
  /// explicitly passed in.
  final String? buyerEmail;

  /// The ticket record created for this purchase, if the caller made one.
  /// When present, "View My Ticket" jumps straight to it instead of just
  /// landing on the My Tickets list.
  final Ticket? purchasedTicket;

  void _handleViewMyTicket(BuildContext context) {
    navigateToTab(context, 1);
    final ticket = purchasedTicket;
    if (ticket != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedEmail = buyerEmail ?? UserSession.instance.account?.email ?? 'your email';
    return Scaffold(
      body: GradientBackground(
        gradient: AppGradients.confirmation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: AppColors.white.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.accentPurple, size: 40),
              ),
              const SizedBox(height: 26),
              Text('Ticket Confirmed!', style: AppTextStyles.heading, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Your ticket has been added to your wallet. A confirmation has been sent to\n$resolvedEmail.',
                textAlign: TextAlign.center,
                style: AppTextStyles.tagline,
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tier.name} \u2013 ${event.title}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.white),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tier.name.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryText),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.fieldBorder, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.white),
                        const SizedBox(width: 8),
                        Text(event.dateLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 15, color: AppColors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(event.venue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              PillButton(
                label: 'View My Ticket',
                onPressed: () => _handleViewMyTicket(context),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => navigateToTab(context, 0),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.white, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text(
                    'Browse More Events',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
                  ),
                ),
              ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
