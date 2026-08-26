import 'package:flutter/material.dart';

import '../../data/sample_events.dart';
import '../../data/sample_notifications.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';
import '../../widgets/featured_event_card.dart';
import '../../widgets/upcoming_event_tile.dart';
import 'all_events_screen.dart';
import 'event_details_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.userFirstName = 'Heron Dave'});

  final String userFirstName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';

  List<EventSummary> get _events {
    if (_searchQuery.isEmpty) return sampleEvents;
    final query = _searchQuery.toLowerCase();
    return sampleEvents.where((e) => e.title.toLowerCase().contains(query)).toList();
  }

  void _openEvent(EventSummary event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // Notifications may have been marked as read while we were away —
    // refresh so the unread dot on the bell reflects that.
    if (mounted) setState(() {});
  }

  void _openAllEvents() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AllEventsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const Row(
                    children: [
                      Icon(Icons.confirmation_number_rounded, color: AppColors.accentPurple, size: 22),
                      SizedBox(width: 6),
                      Text(
                        'FairTix',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _openNotifications,
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_none_rounded, color: AppColors.accentPurple, size: 20),
                        ),
                        if (sampleNotifications.any((n) => !n.isRead))
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.pageBackground, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Welcome, ${widget.userFirstName}!', style: AppTextStyles.sectionHeading),
              const SizedBox(height: 4),
              const Text('Ready for your next event?', style: AppTextStyles.bodyMuted),
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
                    hintText: 'Search events...',
                    hintStyle: AppTextStyles.bodyMuted,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Featured Events', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.accentPurple)),
                  TextButton(
                    onPressed: _openAllEvents,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    child: const Text('See all', style: AppTextStyles.bodyMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('No events match your search.', style: AppTextStyles.bodyMuted),
                  ),
                )
              else
                SizedBox(
                  height: 190,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _events.length,
                    itemBuilder: (context, index) => FeaturedEventCard(
                      event: _events[index],
                      onTap: () => _openEvent(_events[index]),
                    ),
                  ),
                ),
              const SizedBox(height: 26),
              const Text('Upcoming Events', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 6),
              ..._events.map((e) => UpcomingEventTile(event: e, onTap: () => _openEvent(e))),
            ],
          ),
        ),
      ),
    );
  }
}
