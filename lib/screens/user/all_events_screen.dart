import 'package:flutter/material.dart';

import '../../data/sample_events.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';
import '../../widgets/purple_header_bar.dart';
import '../../widgets/upcoming_event_tile.dart';
import 'event_details_screen.dart';

/// Full event catalogue, reached via "See all" on the Dashboard's
/// Featured Events section.
/// TODO: replace `sampleEvents` with a real query against the EVENTS
/// Firestore collection (status == published) once the backend is wired up.
class AllEventsScreen extends StatefulWidget {
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  String _searchQuery = '';

  List<EventSummary> get _filteredEvents {
    if (_searchQuery.isEmpty) return sampleEvents;
    final query = _searchQuery.toLowerCase();
    return sampleEvents.where((e) => e.title.toLowerCase().contains(query)).toList();
  }

  void _openEvent(EventSummary event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'All Events',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text('No events match your search.', style: AppTextStyles.bodyMuted),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const Divider(color: AppColors.inputBorderLight, height: 1),
                      itemBuilder: (context, index) => UpcomingEventTile(
                        event: events[index],
                        onTap: () => _openEvent(events[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
