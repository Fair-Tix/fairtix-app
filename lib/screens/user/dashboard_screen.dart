import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/sample_notifications.dart';
import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../navigation/tab_index_notifier.dart';
import '../../services/notification_repository.dart';
import '../../services/public_event_repository.dart';
import '../../services/ticket_repository.dart';
import '../../services/user_auth_service.dart';
import '../../services/user_session.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart';
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import 'all_events_screen.dart';
import 'event_details_screen.dart';
import 'notifications_screen.dart';

/// Home tab. Dark redesign; one screen with two ticket states (new user /
/// owns tickets). Events, notifications, search and navigation are the same
/// as before, and the ticket numbers come from the existing
/// [TicketRepository], the same data the My Tickets tab shows.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const int _entranceMs = 650;
  static const int _upcomingLimit = 5;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _entranceMs),
  );
  bool _entranceStarted = false;

  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  /// False until tickets have loaded once (see [FtTicketSection.ready]).
  bool _ticketsReady = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadTickets();
    _refreshUnread();
    mainShellTabIndex.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    // Plays once, when the dashboard first opens. The tab is kept alive by
    // the shell, so coming back to Home never replays it.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    mainShellTabIndex.removeListener(_onTabChanged);
    _entrance.dispose();
    super.dispose();
  }

  // The Home tab stays alive in the shell, so a purchase or resale made
  // elsewhere would otherwise not show in the counts until a pull-to-refresh.
  void _onTabChanged() {
    if (mainShellTabIndex.value == 0) {
      _loadTickets();
      _refreshUnread();
    }
  }

  /// Checks for new notifications so the bell's unread dot is accurate
  /// as soon as the dashboard opens.
  Future<void> _refreshUnread() async {
    await NotificationRepository.instance.refreshUnreadCount();
    if (mounted) setState(() {});
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
    // Refresh the bell's unread dot too. A notification failure shouldn't
    // block or error the events list, so it's swallowed here (the
    // notifications screen itself shows load errors).
    try {
      await NotificationRepository.instance.refresh();
      if (mounted) setState(() {});
    } on NotificationRepositoryException {
      // ignore
    }
  }

  /// Pulls the user's tickets through the existing repository. A failure
  /// keeps whatever it already holds (saved offline copy or nothing); the
  /// My Tickets tab is where load errors are shown.
  Future<void> _loadTickets() async {
    try {
      await TicketRepository.instance.refresh();
    } catch (_) {
      // Keep the current data.
    }
    if (mounted) setState(() => _ticketsReady = true);
  }

  /// Falls back to "Eventgoer" if no session is signed in yet (shouldn't
  /// normally happen, since the Dashboard is only reachable after login).
  String get _userFirstName {
    final fullName = UserSession.instance.account?.fullName;
    if (fullName == null || fullName.trim().isEmpty) return 'Eventgoer';
    return fullName.trim().split(RegExp(r'\s+')).first;
  }

  List<EventSummary> get _events {
    final all = PublicEventRepository.instance.events;
    if (_searchQuery.isEmpty) return all;
    final query = _searchQuery.toLowerCase();
    return all.where((e) => e.title.toLowerCase().contains(query)).toList();
  }

  void _openEvent(EventSummary event) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)))
        // A purchase may have happened in there; update the counts.
        .then((_) => _loadTickets());
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // Notifications may have been marked as read while we were away —
    // refresh so the unread dot on the bell reflects that.
    await NotificationRepository.instance.refreshUnreadCount();
    if (mounted) setState(() {});
  }

  void _openAllEvents() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AllEventsScreen()),
    );
  }

  /// Same tab switch the bottom navigation uses.
  void _goToTab(int index) => mainShellTabIndex.value = index;

  Future<void> _refreshAll() => Future.wait([_loadEvents(), _loadTickets()]);

  Widget _loadingOrMessage(String text, {VoidCallback? retry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: FtText.subtitle().copyWith(color: FtColors.otpSecondary),
            ),
            if (retry != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: retry,
                child: Text('Try again', style: FtText.link()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = UserSession.instance.account;
    final photoPath = account?.profilePhotoUrl;
    final photoUrl = photoPath == null
        ? null
        : UserAuthService.instance.profilePhotoPublicUrl(photoPath);

    final events = _events;
    final featured = events.isEmpty ? null : events.first;
    final upcoming = events.skip(1).take(_upcomingLimit).toList();

    final tickets = TicketRepository.instance.tickets;
    final listedCount =
        tickets.where((t) => t.status == TicketStatus.listed).length;

    // Only show the full-screen spinner on the very first load, so a
    // pull-to-refresh doesn't blank the list (and replay the card entrance).
    final firstLoad =
        _isLoading && PublicEventRepository.instance.events.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: FtColors.bgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: FtColors.bgBottom,
        body: FtBackground(
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: FtColors.progressEnd,
              backgroundColor: FtColors.otpFill,
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(19, 14, 19, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FtReveal(
                      animation: _entrance,
                      startMs: 0,
                      endMs: 300,
                      totalMs: _entranceMs,
                      child: ValueListenableBuilder<int>(
                        valueListenable: NotificationRepository.instance.unreadCount,
                        builder: (context, unread, _) => FtDashboardHeader(
                          hasUnread: unread > 0 ||
                              sampleNotifications.any((n) => !n.isRead),
                          onBell: _openNotifications,
                          onProfile: () => _goToTab(3),
                          initial: _userFirstName.substring(0, 1).toUpperCase(),
                          photoUrl: photoUrl,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FtReveal(
                      animation: _entrance,
                      startMs: 60,
                      endMs: 400,
                      totalMs: _entranceMs,
                      slide: 12,
                      child: FtWelcome(name: _userFirstName),
                    ),
                    const SizedBox(height: 20),
                    FtReveal(
                      animation: _entrance,
                      startMs: 120,
                      endMs: 470,
                      totalMs: _entranceMs,
                      slide: 12,
                      child: FtSearchField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (firstLoad)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: CircularProgressIndicator(color: FtColors.progressEnd),
                        ),
                      )
                    else if (_errorMessage != null && events.isEmpty)
                      _loadingOrMessage(_errorMessage!, retry: _loadEvents)
                    else ...[
                      if (featured != null) ...[
                        FtFeaturedCard(
                          event: featured,
                          onTap: () => _openEvent(featured),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FtTicketSection(
                        ready: _ticketsReady,
                        ticketCount: tickets.length,
                        listedCount: listedCount,
                        onBrowse: _openAllEvents,
                        onOpenTickets: () => _goToTab(1),
                        onOpenResale: () => _goToTab(2),
                      ),
                      const SizedBox(height: 28),
                      FtSectionHeader(
                        title: 'Upcoming Events',
                        actionLabel: 'View all',
                        onAction: _openAllEvents,
                      ),
                      const SizedBox(height: 14),
                      if (events.isEmpty)
                        _loadingOrMessage(
                          _searchQuery.isEmpty
                              ? 'No events available yet. Check back soon!'
                              : 'No events match your search.',
                        )
                      else if (upcoming.isEmpty)
                        _loadingOrMessage('No other upcoming events yet.')
                      else
                        for (final e in upcoming) ...[
                          FtUpcomingCard(event: e, onTap: () => _openEvent(e)),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
