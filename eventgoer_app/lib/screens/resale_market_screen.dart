import 'package:flutter/material.dart';

import '../data/sample_resale_listings.dart';
import '../data/sample_tickets.dart';
import '../models/ticket.dart';
import '../theme/app_theme.dart';
import '../widgets/market_listing_card.dart';
import '../widgets/my_listing_card.dart';
import '../widgets/resale_filter_chip.dart';
import 'resale_checkout_screen.dart';
import 'ticket_detail_screen.dart';

/// "Resale Market" tab — browse other users' active resale listings, and
/// see the current user's own listed tickets at the top.
class ResaleMarketScreen extends StatefulWidget {
  const ResaleMarketScreen({super.key});

  @override
  State<ResaleMarketScreen> createState() => _ResaleMarketScreenState();
}

class _ResaleMarketScreenState extends State<ResaleMarketScreen> {
  static const _categories = ['All', 'Concerts', 'Sports', 'Theater'];
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // TODO: `sampleMyTickets`/`sampleResaleListings` are in-memory demo data.
  // Replace with a live query against RESALE_LISTINGS once the resale
  // backend is wired up. Category chips are currently cosmetic only —
  // sample events don't carry a category field yet.
  //
  // Listings whose event has passed the 24-hour resale-closing window are
  // excluded here entirely, mirroring the study's rule that active
  // listings automatically close 24 hours before the event and any
  // unsold ticket is returned to its owner — an expired listing simply
  // shouldn't still be visible in the market.
  List<Ticket> get _myListings => sampleMyTickets
      .where((t) => t.status == TicketStatus.listed && !t.event.isResaleWindowClosed)
      .toList();

  List<Ticket> get _marketListings {
    final active = sampleResaleListings.where((t) => !t.event.isResaleWindowClosed);
    if (_searchQuery.isEmpty) return active.toList();
    final query = _searchQuery.toLowerCase();
    return active.where((t) => t.event.title.toLowerCase().contains(query)).toList();
  }

  void _openMyTicket(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
    );
  }

  void _buyListing(Ticket listing) {
    if (isPurchaseLimitReached(listing.event.id)) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResaleCheckoutScreen(listing: listing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myListings = _myListings;
    final marketListings = _marketListings;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Resale Market', style: AppTextStyles.sectionHeading),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppColors.accentPurple, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Buy and sell tickets safely', style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.inputFillLight,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.inputBorderLight),
                      ),
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search, color: AppColors.accentPurple, size: 20),
                          hintText: 'Search resale tickets...',
                          hintStyle: AppTextStyles.bodyMuted,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return ResaleFilterChip(
                            label: category,
                            isSelected: category == _selectedCategory,
                            onTap: () => setState(() => _selectedCategory = category),
                          );
                        },
                      ),
                    ),
                    if (myListings.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'MY LISTED TICKETS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accentPurple, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 10),
                      ...myListings.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MyListingCard(ticket: t, onTap: () => _openMyTicket(t)),
                          )),
                    ],
                    const SizedBox(height: 22),
                    const Text(
                      'MARKET LISTINGS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accentPurple, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 10),
                    if (marketListings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text('No resale tickets match your search.', style: AppTextStyles.bodyMuted),
                        ),
                      )
                    else
                      ...marketListings.map((listing) => MarketListingCard(
                            listing: listing,
                            isBlocked: isPurchaseLimitReached(listing.event.id),
                            onBuyNow: () => _buyListing(listing),
                          )),
                  ],
          ),
        ),
      ),
    );
  }
}
