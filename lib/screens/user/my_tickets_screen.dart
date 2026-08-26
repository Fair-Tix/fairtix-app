import 'package:flutter/material.dart';

import '../../data/sample_tickets.dart';
import '../../models/ticket.dart';
import '../../theme/app_theme.dart';
import 'ticket_detail_screen.dart';

/// "My Tickets" tab — lists every ticket the current user owns.
/// TODO: replace `sampleMyTickets` with a real query against the TICKETS
/// Firestore collection filtered by owner_id == current user.
class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  void _openTicket(BuildContext context, Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tickets = sampleMyTickets;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Tickets', style: AppTextStyles.sectionHeading),
                          const SizedBox(height: 4),
                          const Text('Tickets you\u2019ve purchased or received', style: AppTextStyles.bodyMuted),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  if (tickets.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 48, color: AppColors.accentPurple.withValues(alpha: 0.35)),
                            const SizedBox(height: 14),
                            const Text('No tickets yet', style: AppTextStyles.sectionHeading),
                            const SizedBox(height: 6),
                            const Text('Tickets you buy will show up here.', style: AppTextStyles.bodyMuted),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList.builder(
                        itemCount: tickets.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TicketCard(
                            ticket: tickets[index],
                            onTap: () => _openTicket(context, tickets[index]),
                          ),
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  ({String label, Color color}) get _statusBadge => switch (ticket.status) {
        TicketStatus.valid => (label: 'Valid', color: AppColors.success),
        TicketStatus.listed => (label: 'Listed', color: AppColors.accentPurple),
        TicketStatus.used => (label: 'Used', color: AppColors.textMuted),
      };

  @override
  Widget build(BuildContext context) {
    final badge = _statusBadge;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: ticket.event.accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.confirmation_number_rounded, color: AppColors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ticket.tier.name.toUpperCase(),
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ticket.event.dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: badge.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge.label,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: badge.color),
                  ),
                ),
                const SizedBox(height: 14),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
