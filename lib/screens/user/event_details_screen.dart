import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/sample_tickets.dart';
import '../../models/event.dart';
import '../../navigation/app_nav.dart';
import '../../services/access_control.dart';
import '../../services/public_event_repository.dart';
import '../../services/ticket_repository.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtBackButton, FtPressScale;
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import 'checkout_screen.dart';

/// Event Details — banner, info, ticket tiers and the buy button. Follows the
/// Light / Dark switch.
///
/// The banner is the image the organizer uploads when creating or editing
/// the event (`events.banner_image_url`, delivered as
/// [EventSummary.bannerUrl]). Without one, a purple placeholder is shown.
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

class _EventDetailsScreenState extends State<EventDetailsScreen>
    with SingleTickerProviderStateMixin {
  static const int _entranceMs = 800;

  TicketTier? _selectedTier;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _entranceMs),
  );
  bool _entranceStarted = false;

  /// The freshest copy of this event (tiers include the latest
  /// remaining_quantity). Falls back to the one passed in if the
  /// repository doesn't have it cached.
  EventSummary get _event => PublicEventRepository.instance.getById(widget.event.id) ?? widget.event;

  /// For a multi-day event, the day currently shown. Each day is its own
  /// event (own tiers, own one-ticket-per-day limit), so tiers, the limit
  /// check and checkout all follow this day. Null for single-day events.
  EventSummary? _selectedDay;

  /// The event actually being viewed/bought: the chosen day of a
  /// multi-day event (using the freshest copy of that day), or the event
  /// itself.
  EventSummary get _activeEvent {
    final day = _selectedDay;
    if (day == null) return _event;
    return _event.days.firstWhere((d) => d.id == day.id, orElse: () => day);
  }

  @override
  void initState() {
    super.initState();
    if (widget.event.isMultiDay) {
      _selectedDay = widget.event.days.first;
    }
    _reloadEvent();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Reloads the catalogue so tier availability is current. Failures are
  /// ignored — the screen just keeps showing the data it already has.
  Future<void> _reloadEvent() async {
    try {
      await PublicEventRepository.instance.refresh();
    } on PublicEventRepositoryException {
      // keep showing cached data
    }
    if (mounted) setState(() {});
  }

  /// Whether FairTix's one-ticket-per-account-per-event purchase limit
  /// blocks the current user from buying a ticket for this event day
  /// because they already hold one. (A user who already RESOLD their ticket
  /// is refused by the server when they try to buy; see isPurchaseLimitReached.)
  bool get _limitReached {
    if (widget.readOnly) return false;
    // One ticket per account per event DAY: every showing of the selected day
    // counts together (the server enforces the same rule).
    final active = _activeEvent;
    final ids = <String>{
      active.id,
      for (final d in _event.days)
        if (d.dayLabel == active.dayLabel) d.id,
    };
    return ids.any(isPurchaseLimitReached);
  }

  /// The distinct days of a multi-day event, in order (several showings on the
  /// same date make ONE day).
  List<String> _distinctDayLabels(EventSummary e) {
    final labels = <String>[];
    for (final d in e.days) {
      if (!labels.contains(d.dayLabel)) labels.add(d.dayLabel);
    }
    return labels;
  }

  /// Every showing on the currently selected day, in time order.
  List<EventSummary> _showingsOnSelectedDay(EventSummary e) {
    final label = _selectedDay?.dayLabel;
    if (label == null) return const [];
    return [for (final d in e.days) if (d.dayLabel == label) d];
  }

  Future<void> _handleBuyTicket() async {
    final selected = _selectedTier;
    if (selected == null || _limitReached) return;
    // Buying needs an admin-approved account. Browsing stays open; this
    // explains why checkout is locked (the database refuses it as well).
    if (!await ensureBuyerApproved(context)) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    // Use the latest copy of the selected tier (matched by id) so checkout
    // sees current availability.
    final active = _activeEvent;
    final tier = active.tiers.firstWhere((t) => t.id == selected.id, orElse: () => selected);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(event: active, tier: tier),
      ),
    );
    // Back from checkout/confirmation: pull the new remaining quantity.
    if (mounted) await _reloadEvent();
  }

  void _handleViewMyTicket() {
    navigateToTab(context, 1);
  }

  /// "₱3,000" style, or "Free".
  static String _pesoShort(double price) =>
      price <= 0 ? 'Free' : formatPeso(price).replaceAll('.00', '');

  /// Bottom button text: the chosen tier's price once one is picked,
  /// otherwise the starting price.
  String get _buttonLabel {
    if (_limitReached) return 'Purchase Limit Reached';
    final tiers = _activeEvent.tiers;
    if (_selectedTier != null) {
      return 'Get Ticket \u00B7 ${_pesoShort(_selectedTier!.price)}';
    }
    if (tiers.isEmpty) return 'Get Ticket';
    final lowest = tiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    return 'Get Ticket \u00B7 From ${_pesoShort(lowest)}';
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final lock = widget.readOnly ? null : buyerLockMessage(UserSession.instance.account);
    final topInset = MediaQuery.paddingOf(context).top;
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.33).clamp(240.0, 340.0);
    final t = FtAuthTheme.live(context);

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      // Status bar icons stay light in both modes: the banner (or its purple
      // placeholder) sits right under them.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: t.bgBottom,
        systemNavigationBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: FtReveal(
                          animation: _entrance,
                          startMs: 0,
                          endMs: 350,
                          totalMs: _entranceMs,
                          child: _EventBanner(url: event.bannerUrl, height: heroHeight),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.5],
                              colors: [
                                t.isDark ? const Color(0xFF0E0829) : t.bgTop,
                                t.bgBottom,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FtReveal(
                                  animation: _entrance,
                                  startMs: 150,
                                  endMs: 500,
                                  totalMs: _entranceMs,
                                  slide: 14,
                                  child: _buildInfo(event, t),
                                ),
                                if (event.isMultiDay) ...[
                                  const SizedBox(height: 22),
                                  _SectionLabel('Event days (${_distinctDayLabels(event).length})'),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (var i = 0; i < _distinctDayLabels(event).length; i++)
                                        _DayChip(
                                          label: 'Day ${i + 1} \u2022 ${_distinctDayLabels(event)[i]}',
                                          selected: _selectedDay?.dayLabel == _distinctDayLabels(event)[i],
                                          onTap: () => setState(() {
                                            _selectedDay = event.days.firstWhere(
                                              (d) => d.dayLabel == _distinctDayLabels(event)[i],
                                            );
                                            _selectedTier = null; // tiers differ per day
                                          }),
                                        ),
                                    ],
                                  ),
                                ],
                                if (event.isMultiDay &&
                                    _showingsOnSelectedDay(event).any((s) => s.timeLabel != null)) ...[
                                  const SizedBox(height: 22),
                                  const _SectionLabel('Showtime'),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final s in _showingsOnSelectedDay(event))
                                        _DayChip(
                                          label: s.timeLabel ?? 'Showing',
                                          selected: _selectedDay?.id == s.id,
                                          onTap: () => setState(() {
                                            _selectedDay = s;
                                            _selectedTier = null; // each showtime has its own tickets
                                          }),
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 22),
                                const _SectionLabel('Tickets'),
                                if (event.isFullRunPass) ...[
                                  const SizedBox(height: 12),
                                  const _Notice(
                                    icon: Icons.confirmation_number_outlined,
                                    title: 'One pass for all days',
                                    message:
                                        'One ticket covers every day of this event. Your QR code is scanned once per day.',
                                  ),
                                ],
                                const SizedBox(height: 12),
                                if (lock != null) ...[
                                  _Notice(
                                    icon: Icons.lock_outline_rounded,
                                    title: 'Buying tickets is locked',
                                    message: lock,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (_limitReached) ...[
                                  _Notice(
                                    icon: Icons.info_outline_rounded,
                                    title: 'You already have a ticket for this event',
                                    message: 'FairTix allows one ticket per account per event day. All showtimes of a day count together.',
                                    actionLabel: 'View My Ticket',
                                    onAction: _handleViewMyTicket,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (widget.readOnly) ...[
                                  const _Notice(
                                    icon: Icons.visibility_outlined,
                                    title: 'View only',
                                    message: 'You\u2019re viewing this event. Only event goers can buy tickets.',
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (_activeEvent.tiers.isEmpty)
                                  Text(
                                    'No ticket tiers have been set up yet.',
                                    style: FtText.subtitle().copyWith(color: t.secondaryText),
                                  ),
                                for (var i = 0; i < _activeEvent.tiers.length; i++) ...[
                                  _tierReveal(
                                    i,
                                    _TierCard(
                                      tier: _activeEvent.tiers[i],
                                      selected: _selectedTier?.id == _activeEvent.tiers[i].id,
                                      onTap: (_limitReached || widget.readOnly)
                                          ? null
                                          : () => setState(() => _selectedTier = _activeEvent.tiers[i]),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: topInset + 14,
                    left: 22,
                    child: FtReveal(
                      animation: _entrance,
                      startMs: 0,
                      endMs: 300,
                      totalMs: _entranceMs,
                      child: FtBackButton(onTap: () => Navigator.of(context).maybePop()),
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.readOnly)
              FtReveal(
                animation: _entrance,
                startMs: 300,
                endMs: 650,
                totalMs: _entranceMs,
                slide: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.bgBottom,
                    border: Border(top: BorderSide(color: t.surfaceBorder)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                      child: FtGradientButton(
                        label: _buttonLabel,
                        onPressed: (_selectedTier != null && !_limitReached) ? _handleBuyTicket : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _tierReveal(int index, Widget child) {
    if (index >= 4) return child;
    return FtReveal(
      animation: _entrance,
      startMs: 250 + index * 50,
      endMs: 250 + index * 50 + 300,
      totalMs: _entranceMs,
      slide: 12,
      child: child,
    );
  }

  Widget _buildInfo(EventSummary event, FtAuthTheme t) {
    final hasDescription = event.description != null && event.description!.trim().isNotEmpty;
    TextStyle meta() => GoogleFonts.plusJakartaSans(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: t.secondaryText,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            event.title,
            style: FtText.title().copyWith(
              fontSize: 34,
              letterSpacing: -0.6,
              color: t.titleColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 17, color: t.secondaryText),
                const SizedBox(width: 8),
                Flexible(child: Text(event.dateLabel, style: meta())),
              ],
            ),
            Text('\u2022', style: meta()),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 17, color: t.secondaryText),
                const SizedBox(width: 6),
                Flexible(child: Text(event.venue, style: meta())),
              ],
            ),
          ],
        ),
        if (hasDescription) ...[
          const SizedBox(height: 24),
          const _SectionLabel('About'),
          const SizedBox(height: 10),
          Text(
            event.description!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.5,
              color: t.secondaryText,
            ),
          ),
        ],
      ],
    );
  }
}

/// The event's banner. Fades in once loaded; a purple placeholder shows while
/// loading, when the organizer hasn't uploaded one, or if it fails to load.
class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.url, required this.height});

  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B2FC4), Color(0xFF3A1F8F)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.confirmation_number_outlined,
          size: 64,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    );

    const shade = Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 110,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x66000000), Color(0x00000000)],
          ),
        ),
      ),
    );

    // No banner (or it can't load): the purple placeholder at the usual height.
    Widget fallback() => SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(fit: StackFit.expand, children: [placeholder, shade]),
        );
    if (url == null) return fallback();

    // The organizer's picture is shown whole: full width, height follows the
    // picture. A very tall one is capped at 1.25x the width and shown without
    // cropping (bars at the sides).
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxWidth * 1.25),
            child: ColoredBox(
              color: const Color(0xFF0E0829),
              child: Image.network(
                url!,
                fit: BoxFit.contain,
                width: double.infinity,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                // While loading: the placeholder at the usual height.
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : SizedBox(width: double.infinity, height: height, child: placeholder),
                errorBuilder: (_, _, _) => fallback(),
              ),
            ),
          ),
          // Soft shade at the top so the back button stays visible on
          // bright photos.
          shade,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: t.secondaryText,
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? const LinearGradient(
                    colors: [FtColors.progressStart, FtColors.otpButtonEnd],
                  )
                : null,
            color: selected
                ? null
                : (t.isDark ? t.surfaceFill.withValues(alpha: 0.75) : t.surfaceFill),
            border: Border.all(color: selected ? Colors.transparent : t.surfaceBorder),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.2,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: selected ? Colors.white : t.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable ticket tier. A null [onTap] (purchase limit reached, or
/// view-only) dims it; a sold-out tier is dimmed and can't be picked.
class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.selected, required this.onTap});

  final TicketTier tier;
  final bool selected;
  final VoidCallback? onTap;

  bool get _disabled => onTap == null || tier.isSoldOut;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final remaining = tier.remainingQuantity;
    final lowStock = !tier.isSoldOut && remaining != null && remaining <= 10;

    final String subtitle = tier.isSoldOut
        ? 'Sold out'
        : lowStock
            ? 'Only $remaining left'
            : '1 ticket per account';
    final Color subtitleColor = tier.isSoldOut
        ? t.danger
        : lowStock
            ? AppColors.warning
            : t.secondaryText;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !_disabled,
      label: '${tier.name}, ${_priceText(tier)}, $subtitle',
      excludeSemantics: true,
      child: Opacity(
        opacity: _disabled ? 0.45 : 1,
        child: FtPressScale(
          onTap: tier.isSoldOut ? null : onTap,
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FtColors.progressStart.withValues(alpha: 0.34),
                        FtColors.progressStart.withValues(alpha: 0.16),
                      ],
                    )
                  : null,
              color: selected
                  ? null
                  : (t.isDark ? t.surfaceFill.withValues(alpha: 0.75) : t.surfaceFill),
              border: Border.all(
                color: selected ? t.fieldBorderFocused : t.surfaceBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: t.titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: lowStock || tier.isSoldOut ? FontWeight.w700 : FontWeight.w400,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _priceText(tier),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 23,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: t.titleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _priceText(TicketTier tier) =>
      tier.price <= 0 ? 'Free' : formatPeso(tier.price).replaceAll('.00', '');
}

/// Info box used for the locked-buying, purchase-limit and view-only
/// messages.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: t.titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.4,
                    color: t.secondaryText,
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onAction,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(actionLabel!, style: t.link()),
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
