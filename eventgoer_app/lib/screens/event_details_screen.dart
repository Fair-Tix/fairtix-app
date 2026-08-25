import 'package:flutter/material.dart';

import '../data/sample_tickets.dart';
import '../models/event.dart';
import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/ticket_tier_row.dart';
import 'checkout_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event});

  final EventSummary event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  TicketTier? _selectedTier;

  /// Whether FairTix's one-ticket-per-account-per-event purchase limit
  /// blocks the current user from buying a ticket for this event —
  /// either because they already hold one, or because they've already
  /// resold their ticket for it.
  bool get _limitReached => isPurchaseLimitReached(widget.event.id);

  bool get _alreadyOwnsTicket => userOwnsTicketForEvent(widget.event.id);

  void _handleBuyTicket() {
    final tier = _selectedTier;
    if (tier == null || _limitReached) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(event: widget.event, tier: tier),
      ),
    );
  }

  void _handleViewMyTicket() {
    navigateToTab(context, 1);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(color: event.accentColor),
                  child: Center(
                    child: Icon(Icons.music_note_rounded, size: 72, color: AppColors.white.withValues(alpha: 0.35)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: AppTextStyles.sectionHeading),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.accentPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.dateLabel,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: AppColors.accentPurple),
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
                      if (event.description != null)
                        Text(event.description!, style: AppTextStyles.bodyMuted.copyWith(height: 1.5)),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Ticket Tiers',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_limitReached) ...[
                        _PurchaseLimitNotice(
                          alreadyOwnsTicket: _alreadyOwnsTicket,
                          onViewMyTicket: _alreadyOwnsTicket ? _handleViewMyTicket : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      ...event.tiers.map(
                        (tier) => TicketTierRow(
                          tier: tier,
                          isSelected: _selectedTier == tier,
                          onTap: _limitReached ? null : () => setState(() => _selectedTier = tier),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(Icons.confirmation_number_outlined, size: 14, color: AppColors.accentPurple),
                          SizedBox(width: 6),
                          Text(
                            '1 ticket per account per event',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.accentPurple),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 48,
            left: 16,
            child: _BackCircleButton(onTap: () => Navigator.of(context).maybePop()),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.pageBackground,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
                ],
              ),
              child: GradientPillButton(
                label: _limitReached ? 'Purchase Limit Reached' : 'Buy Ticket',
                onPressed: (_selectedTier != null && !_limitReached) ? _handleBuyTicket : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on the Event Details screen in place of ticket-tier selection
/// when FairTix's one-ticket-per-account-per-event purchase limit blocks
/// the current user from buying — either because they still hold a
/// ticket for this event, or because they've already resold one.
class _PurchaseLimitNotice extends StatelessWidget {
  const _PurchaseLimitNotice({required this.alreadyOwnsTicket, this.onViewMyTicket});

  final bool alreadyOwnsTicket;
  final VoidCallback? onViewMyTicket;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alreadyOwnsTicket ? 'You already have a ticket for this event' : 'Purchase limit reached for this event',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.warning),
                ),
                const SizedBox(height: 4),
                Text(
                  alreadyOwnsTicket
                      ? 'FairTix allows one ticket per account per event.'
                      : 'You\u2019ve already resold your ticket for this event, so you can\u2019t purchase another one.',
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 12, height: 1.35),
                ),
                if (onViewMyTicket != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onViewMyTicket,
                    child: const Text(
                      'View My Ticket',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.accentPurple, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackCircleButton extends StatelessWidget {
  const _BackCircleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 20),
      ),
    );
  }
}
