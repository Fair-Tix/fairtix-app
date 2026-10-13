import 'package:flutter/material.dart';

import '../../data/sample_tickets.dart';
import '../../models/event.dart';
import '../../navigation/app_nav.dart';
import '../../services/ticket_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/ticket_tier_row.dart';
import 'checkout_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event, this.readOnly = false});

  final EventSummary event;

  /// True when an organizer or admin is browsing the catalogue: the event
  /// is shown in full, but nothing can be selected or bought (only event
  /// goers purchase tickets).
  final bool readOnly;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  TicketTier? _selectedTier;

  /// For a multi-day event, the day currently shown. Each day is its own
  /// event (own tiers, own one-ticket-per-day limit), so tiers, the limit
  /// check and checkout all follow this day. Null for single-day events.
  EventSummary? _selectedDay;

  /// The event actually being viewed/bought: the chosen day of a
  /// multi-day event, or the event itself.
  EventSummary get _activeEvent => _selectedDay ?? widget.event;

  @override
  void initState() {
    super.initState();
    if (widget.event.isMultiDay) {
      _selectedDay = widget.event.days.first;
    }
    // Refresh the owned-tickets cache so the one-ticket-per-account limit
    // check below reflects any purchase made since this cache was last
    // loaded (e.g. from another device, or earlier this session).
    // (Skipped for organizers/admins, who can't buy tickets here.)
    if (!widget.readOnly) {
      TicketRepository.instance.refresh().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Whether FairTix's one-ticket-per-account-per-event purchase limit
  /// blocks the current user from buying a ticket for this event —
  /// either because they already hold one, or because they've already
  /// resold their ticket for it.
  bool get _limitReached => !widget.readOnly && isPurchaseLimitReached(_activeEvent.id);

  bool get _alreadyOwnsTicket => userOwnsTicketForEvent(_activeEvent.id);

  void _handleBuyTicket() {
    final tier = _selectedTier;
    if (tier == null || _limitReached) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(event: _activeEvent, tier: tier),
      ),
    );
  }

  void _handleViewMyTicket() {
    navigateToTab(context, 1);
  }

  Widget _bannerPlaceholder() {
    return Center(
      child: Icon(Icons.music_note_rounded, size: 72, color: AppColors.white.withValues(alpha: 0.35)),
    );
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
                  clipBehavior: Clip.antiAlias,
                  child: event.bannerUrl != null
                      ? Image.network(
                          event.bannerUrl!,
                          width: double.infinity,
                          height: 280,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) => progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator(color: AppColors.white)),
                          // If the banner can't load, fall back to the placeholder.
                          errorBuilder: (_, _, _) => _bannerPlaceholder(),
                        )
                      : _bannerPlaceholder(),
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
                      if (event.isMultiDay) ...[
                        Text(
                          'Event Days (${event.days.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < event.days.length; i++)
                              ChoiceChip(
                                label: Text('Day ${i + 1} \u2022 ${event.days[i].dateLabel}'),
                                selected: _selectedDay?.id == event.days[i].id,
                                selectedColor: AppColors.accentPurple,
                                labelStyle: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedDay?.id == event.days[i].id ? AppColors.white : AppColors.textDark,
                                ),
                                onSelected: (_) => setState(() {
                                  _selectedDay = event.days[i];
                                  _selectedTier = null; // tiers differ per day
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ],
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
                      if (widget.readOnly) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'You\u2019re viewing this event. Only event goers can buy tickets.',
                            style: AppTextStyles.bodyMuted.copyWith(fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_activeEvent.tiers.isEmpty)
                        Text('No ticket tiers have been set up yet.', style: AppTextStyles.bodyMuted),
                      ..._activeEvent.tiers.map(
                        (tier) => TicketTierRow(
                          tier: tier,
                          isSelected: _selectedTier == tier,
                          onTap: (_limitReached || widget.readOnly) ? null : () => setState(() => _selectedTier = tier),
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
          if (!widget.readOnly)
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
