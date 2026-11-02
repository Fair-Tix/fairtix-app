import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/event.dart';
import '../../services/public_event_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtBackButton, FtSearchField;
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import '../../widgets/purple_header_bar.dart';
import '../../widgets/upcoming_event_tile.dart';
import 'event_details_screen.dart';

/// Full event catalogue, reached via "View all" on the Dashboard's Upcoming
/// Events section. Backed by `public.events` (status == published) via
/// [PublicEventRepository].
///
/// Eventgoers see the redesigned layout, which follows the Light / Dark
/// switch. The organizer and admin portals open this
/// same screen with [readOnly] set; they keep the previous light layout so
/// they still match their own pages.
class AllEventsScreen extends StatefulWidget {
  const AllEventsScreen({super.key, this.readOnly = false});

  /// True when opened from the organizer or admin portal: the same
  /// published catalogue, but events open in view-only mode (no ticket
  /// selection or purchase — only event goers buy tickets).
  final bool readOnly;

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen>
    with SingleTickerProviderStateMixin {
  static const int _revealMs = 650;
  static const int _revealRows = 6;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _revealMs),
  );
  bool _revealStarted = false;
  bool _hadEventsAtStart = false;

  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hadEventsAtStart = PublicEventRepository.instance.events.isNotEmpty;
    _loadEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_revealStarted) return;
    _revealStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    } else if (_hadEventsAtStart) {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
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
      if (mounted) {
        setState(() => _isLoading = false);
        // First time the list appears (nothing was cached): play the rise-in
        // now. Later refreshes don't replay it.
        if (!_hadEventsAtStart &&
            PublicEventRepository.instance.events.isNotEmpty &&
            !MediaQuery.disableAnimationsOf(context)) {
          _hadEventsAtStart = true;
          _reveal.forward(from: 0);
        }
      }
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
      MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event, readOnly: widget.readOnly)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) return _buildLight(context);
    return _buildEventgoer(context);
  }

  // ---------------------------------------------------------------------
  // Eventgoer layout (follows the Light / Dark switch)
  // ---------------------------------------------------------------------

  Widget _buildEventgoer(BuildContext context) {
    final t = FtAuthTheme.live(context);
    final events = _filteredEvents;
    // Spinner only when there is nothing to show yet; a refresh keeps the
    // list on screen.
    final showSpinner =
        _isLoading && PublicEventRepository.instance.events.isEmpty;

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.overlayStyle,
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: FtAuthBackground(
          theme: t,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  child: Row(
                    children: [
                      FtBackButton(onTap: () => Navigator.of(context).maybePop()),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'All Events',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: t.titleColor,
                            ),
                          ),
                        ),
                      ),
                      // Balances the back button so the title stays centered.
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: FtSearchField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: RefreshIndicator(
                    color: t.activeAccent,
                    backgroundColor: t.surfaceFill,
                    onRefresh: _loadEvents,
                    child: showSpinner
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: CircularProgressIndicator(
                                  color: t.activeAccent,
                                ),
                              ),
                            ],
                          )
                        : _errorMessage != null && events.isEmpty
                            ? _darkMessage(_errorMessage!, retry: _loadEvents)
                            : events.isEmpty
                                ? _darkMessage(
                                    _searchQuery.isEmpty
                                        ? 'No events available yet. Check back soon!'
                                        : 'No events match your search.',
                                  )
                                : ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                                    children: [_eventsCard(events)],
                                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _darkMessage(String text, {VoidCallback? retry}) {
    final t = FtAuthTheme.live(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 70),
        Text(
          text,
          textAlign: TextAlign.center,
          style: t.subtitle().copyWith(color: t.secondaryText),
        ),
        if (retry != null)
          Center(
            child: TextButton(
              onPressed: retry,
              child: Text('Try again', style: t.link()),
            ),
          ),
      ],
    );
  }

  Widget _eventsCard(List<EventSummary> events) {
    final t = FtAuthTheme.live(context);
    final rows = <Widget>[];
    for (var i = 0; i < events.length; i++) {
      if (i > 0) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: t.surfaceBorder.withValues(alpha: 0.7),
        ));
      }
      Widget row = _EventRow(event: events[i], onTap: () => _openEvent(events[i]));
      if (i < _revealRows) {
        row = FtReveal(
          animation: _reveal,
          startMs: i * 50,
          endMs: i * 50 + 300,
          totalMs: _revealMs,
          slide: 12,
          child: row,
        );
      }
      rows.add(row);
    }

    return Container(
      decoration: BoxDecoration(
        color: t.isDark ? t.surfaceFill.withValues(alpha: 0.75) : t.surfaceFill,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: t.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: rows),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Previous light layout (organizer / admin read-only browsing)
  // ---------------------------------------------------------------------

  Widget _buildLight(BuildContext context) {
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

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// One row of the eventgoer list: date badge, title and venue, price on the
/// right.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});

  final EventSummary event;
  final VoidCallback onTap;

  /// Month and day text for the badge, e.g. ("OCT", "17") or ("OCT", "14–17")
  /// for a multi-day event.
  ({String month, String day}) get _badge {
    final start = event.eventDateTime;
    if (event.isMultiDay) {
      final end = event.days.last.eventDateTime;
      if (end.year != start.year || end.month != start.month || end.day != start.day) {
        final sameMonth = end.month == start.month && end.year == start.year;
        return (
          month: sameMonth
              ? _months[start.month - 1]
              : '${_months[start.month - 1]}\u2013${_months[end.month - 1]}',
          day: '${start.day}\u2013${end.day}',
        );
      }
    }
    return (month: _months[start.month - 1], day: '${start.day}');
  }

  /// Cheapest tier, as the short label the list shows: "TBA" with no tiers,
  /// "Free" for a free event, otherwise the peso amount without ".00".
  String get _price {
    if (event.tiers.isEmpty) return 'TBA';
    final lowest = event.tiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    if (lowest <= 0) return 'Free';
    final label = formatPeso(lowest);
    return label.endsWith('.00') ? label.substring(0, label.length - 3) : label;
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final badge = _badge;
    final price = _price;
    return Semantics(
      button: true,
      label: '${event.title}, ${event.dateLabel}, ${event.venue}. '
          '${price == 'TBA' || price == 'Free' ? price : 'From $price'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: FtColors.progressStart.withValues(alpha: 0.12),
        highlightColor: FtColors.progressStart.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: FtColors.progressStart.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        badge.month,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: t.activeAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        badge.day,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: t.titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: t.titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.venue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.2,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: Text(
                  price,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: t.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
