import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../services/public_event_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/purple_header_bar.dart';
import '../../widgets/upcoming_event_tile.dart';
import 'event_details_screen.dart';

/// Full event catalogue, reached via "See all" on the Dashboard's
/// Featured Events section. Backed by `public.events` (status ==
/// published) via [PublicEventRepository].
class AllEventsScreen extends StatefulWidget {
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await PublicEventRepository.instance.refresh();
    } on PublicEventRepositoryException catch (e) {
      _errorMessage = e.message;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<EventSummary> get _filteredEvents {
    final all = PublicEventRepository.instance.events;
    if (_searchQuery.isEmpty) return all;
    final query = _searchQuery.toLowerCase();
    return all.where((e) => e.title.toLowerCase().contains(query)).toList();
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
              child: RefreshIndicator(
                onRefresh: _loadEvents,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accentPurple))
                    : _errorMessage != null
                        ? ListView(
                            children: [
                              const SizedBox(height: 60),
                              Center(
                                child: Column(
                                  children: [
                                    Text(_errorMessage!, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
                                    const SizedBox(height: 10),
                                    TextButton(onPressed: _loadEvents, child: const Text('Try again')),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : events.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 60),
                                  Center(
                                    child: Text(
                                      _searchQuery.isEmpty
                                          ? 'No events available yet. Check back soon!'
                                          : 'No events match your search.',
                                      style: AppTextStyles.bodyMuted,
                                    ),
                                  ),
                                ],
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
            ),
          ],
        ),
      ),
    );
  }
}
