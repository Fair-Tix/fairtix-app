import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/event.dart';
import 'ft_dark_ui.dart';
import 'ft_pending_ui.dart' show FtReveal;
import 'ft_verified_ui.dart' show FtVerifiedColors;

/// Building blocks for the redesigned eventgoer dashboard (dark design).
/// Presentation only: every callback and every number is handed in by
/// DashboardScreen, which keeps using the existing repositories.

/// Shrinks its child to 0.97 while pressed (about 120 ms) and calls [onTap].
class FtPressScale extends StatefulWidget {
  const FtPressScale({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<FtPressScale> createState() => _FtPressScaleState();
}

class _FtPressScaleState extends State<FtPressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed && !reduce ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Top row: FairTix logo + wordmark on the left; bell and profile circle on
/// the right.
class FtDashboardHeader extends StatelessWidget {
  const FtDashboardHeader({
    super.key,
    required this.hasUnread,
    required this.onBell,
    required this.onProfile,
    required this.initial,
    this.photoUrl,
  });

  final bool hasUnread;
  final VoidCallback onBell;
  final VoidCallback onProfile;
  final String initial;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const FtLogo(ticketWidth: 40),
        const SizedBox(width: 10),
        Text(
          'FairTix',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Semantics(
          button: true,
          label: hasUnread ? 'Notifications, unread' : 'Notifications',
          excludeSemantics: true,
          child: FtPressScale(
            onTap: onBell,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FtColors.otpFill,
                border: Border.all(color: FtColors.otpBorder),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: 22,
                    color: FtColors.progressEnd,
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 10,
                      right: 11,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: FtColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: FtColors.otpFill, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Profile',
          excludeSemantics: true,
          child: FtPressScale(
            onTap: onProfile,
            child: Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: FtColors.progressStart,
              ),
              alignment: Alignment.center,
              child: photoUrl == null
                  ? _initial()
                  : Image.network(
                      photoUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _initial(),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initial() => Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );
}

/// Dashed perforation line with a half-hidden notch at each card edge, for
/// ticket-style cards. Place it between the two halves of a card whose
/// content is padded 22px from the sides; the notches overlap the card edges.
class FtPerforation extends StatelessWidget {
  const FtPerforation({super.key});

  Widget _notch() => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FtColors.bgBottom,
          border: Border.all(color: FtColors.otpBorder),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: CustomPaint(painter: _PerforationDashes()),
            ),
          ),
          Positioned(left: -11, top: 0, child: _notch()),
          Positioned(right: -11, top: 0, child: _notch()),
        ],
      ),
    );
  }
}

class _PerforationDashes extends CustomPainter {
  const _PerforationDashes();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FtColors.otpBorder
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0, size.width).toDouble(), y), paint);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(_PerforationDashes old) => false;
}

/// Round dark back button used in the headers of the pushed screens.
class FtBackButton extends StatelessWidget {
  const FtBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FtColors.otpFill,
            border: Border.all(color: FtColors.otpBorder),
          ),
          child: const Icon(Icons.chevron_left_rounded, size: 26, color: Colors.white),
        ),
      ),
    );
  }
}

/// The purple profile circle (photo if there is one, otherwise the first
/// letter of the name). [onTap] is the dashboard's existing "open Profile".
class FtProfileAvatar extends StatelessWidget {
  const FtProfileAvatar({
    super.key,
    required this.initial,
    required this.onTap,
    this.photoUrl,
    this.size = 44,
  });

  final String initial;
  final String? photoUrl;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget letter() => Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.41,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        );
    return Semantics(
      button: true,
      label: 'Profile',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [FtColors.progressStart, FtColors.otpButtonEnd],
            ),
          ),
          child: photoUrl == null
              ? letter()
              : Image.network(
                  photoUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => letter(),
                ),
        ),
      ),
    );
  }
}

/// "Welcome back" over the user's first name.
class FtWelcome extends StatelessWidget {
  const FtWelcome({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: FtColors.otpSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FtText.title().copyWith(fontSize: 36, letterSpacing: -0.6),
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped search input. A real [TextField]: [onChanged] is the
/// dashboard's existing search handler.
class FtSearchField extends StatelessWidget {
  const FtSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: c),
        );
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: FtText.input(),
      cursorColor: FtColors.progressEnd,
      decoration: InputDecoration(
        hintText: 'Search events...',
        hintStyle: FtText.input().copyWith(color: FtColors.otpSecondary),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: FtColors.progressEnd,
          size: 22,
        ),
        filled: true,
        fillColor: FtColors.otpFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 8),
        border: border(FtColors.otpBorder),
        enabledBorder: border(FtColors.otpBorder),
        focusedBorder: border(FtColors.fieldBorderFocused),
      ),
    );
  }
}

/// The big purple featured-event card. Whole card is tappable ([onTap] is the
/// dashboard's existing open-event action). Fades and rises once when it
/// first appears.
class FtFeaturedCard extends StatelessWidget {
  const FtFeaturedCard({super.key, required this.event, required this.onTap});

  final EventSummary event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    // The catalogue only holds events that haven't finished, so one whose
    // start date has arrived is on right now.
    final live = !event.eventDateTime.isAfter(DateTime.now());
    final ticketLine =
        event.tiers.isEmpty ? 'Tickets TBA' : event.startingPriceLabel;

    final card = Semantics(
      button: true,
      label: '${event.title}, ${event.dateLabel}, ${event.venue}. View event',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: FtColors.progressEnd.withValues(alpha: 0.28)),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [FtColors.progressStart, FtColors.otpButtonEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: FtColors.glow.withValues(alpha: 0.28),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (event.bannerUrl != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.network(
                      event.bannerUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              // Soft light glow in the top-right corner.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.95, -0.95),
                      radius: 0.95,
                      colors: [
                        FtColors.progressEnd.withValues(alpha: 0.38),
                        FtColors.progressEnd.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Deepens toward the bottom-left, as in the design.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      stops: const [0.0, 0.8],
                      colors: [
                        FtColors.bgTop.withValues(alpha: 0.85),
                        FtColors.bgTop.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: FtColors.bgTop.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: live
                                  ? FtVerifiedColors.green
                                  : FtColors.progressEnd,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            live ? 'Happening now' : 'Coming up',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FtText.title().copyWith(fontSize: 30, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${event.dateLabel} \u2022 ${event.venue}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: FtColors.lavenderBright,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticketLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: FtColors.lavenderBright,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View event',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: FtColors.bgTop,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: FtColors.bgTop,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      child: card,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
    );
  }
}

/// The one ticket block under the featured card. Shows the "No tickets yet"
/// card for a new user, or the two stat cards once they own tickets; the
/// switch between them is animated. Counts come from the dashboard, which
/// reads them from the existing TicketRepository.
class FtTicketSection extends StatelessWidget {
  const FtTicketSection({
    super.key,
    required this.ready,
    required this.ticketCount,
    required this.listedCount,
    required this.onBrowse,
    required this.onOpenTickets,
    required this.onOpenResale,
  });

  /// False until tickets have been loaded once, so a new-user card never
  /// flashes for someone who actually has tickets.
  final bool ready;
  final int ticketCount;
  final int listedCount;
  final VoidCallback onBrowse;
  final VoidCallback onOpenTickets;
  final VoidCallback onOpenResale;

  static const _statsKey = ValueKey('ticket-stats');
  static const _emptyKey = ValueKey('ticket-empty');

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SizedBox(height: 90);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final hasTickets = ticketCount > 0;

    return AnimatedSize(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
        reverseDuration: reduce ? Duration.zero : const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) {
          // Stat cards rise into place; the empty card lifts away.
          final isStats = child.key == _statsKey;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, isStats ? 0.14 : -0.14),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: hasTickets
            ? _StatsRow(
                key: _statsKey,
                ticketCount: ticketCount,
                listedCount: listedCount,
                onOpenTickets: onOpenTickets,
                onOpenResale: onOpenResale,
              )
            : _EmptyTicketsCard(key: _emptyKey, onBrowse: onBrowse),
      ),
    );
  }
}

class _EmptyTicketsCard extends StatelessWidget {
  const _EmptyTicketsCard({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      decoration: BoxDecoration(
        color: FtColors.otpFill.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FtColors.otpBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No tickets yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tickets you buy appear here, tied to your verified account.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: FtColors.otpSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Semantics(
            button: true,
            label: 'Browse events',
            excludeSemantics: true,
            child: FtPressScale(
              onTap: onBrowse,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: FtColors.progressStart.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Browse',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: FtColors.progressEnd,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "My Tickets" and "Listed for resale" side by side. My Tickets enters
/// first, the other 80 ms later; the numbers count up once.
class _StatsRow extends StatefulWidget {
  const _StatsRow({
    super.key,
    required this.ticketCount,
    required this.listedCount,
    required this.onOpenTickets,
    required this.onOpenResale,
  });

  final int ticketCount;
  final int listedCount;
  final VoidCallback onOpenTickets;
  final VoidCallback onOpenResale;

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = 380;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FtReveal(
              animation: _controller,
              startMs: 0,
              endMs: 300,
              totalMs: _totalMs,
              slide: 12,
              scaleFrom: 0.97,
              child: _StatCard(
                icon: Icons.confirmation_number_outlined,
                label: 'My Tickets',
                count: widget.ticketCount,
                onTap: widget.onOpenTickets,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FtReveal(
              animation: _controller,
              startMs: 80,
              endMs: 380,
              totalMs: _totalMs,
              slide: 12,
              scaleFrom: 0.97,
              child: _StatCard(
                icon: Icons.swap_horiz_rounded,
                label: 'Listed for resale',
                count: widget.listedCount,
                onTap: widget.onOpenResale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: '$label: $count',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FtColors.otpFill.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FtColors.otpBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: FtColors.progressStart.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: FtColors.progressEnd),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: FtColors.otpSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: count),
                      duration: reduce ? Duration.zero : const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (context, value, _) => Text(
                        '$value',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Upcoming Events" heading with the light-purple "View all" link.
class FtSectionHeader extends StatelessWidget {
  const FtSectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 21,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
          ),
        ),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              actionLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: FtColors.progressEnd,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One row in the Upcoming Events list: thumbnail, name, date, venue and a
/// small price badge.
class FtUpcomingCard extends StatelessWidget {
  const FtUpcomingCard({super.key, required this.event, required this.onTap});

  final EventSummary event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${event.title}, ${event.dateLabel}, ${event.venue}, ${event.startingPriceLabel}',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FtColors.otpFill.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FtColors.otpBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [FtColors.progressStart, FtColors.bgTop],
                  ),
                ),
                child: event.bannerUrl == null
                    ? null
                    : Image.network(
                        event.bannerUrl!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
                        fontSize: 16.5,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.2,
                        color: FtColors.otpSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: FtColors.otpSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              height: 1.2,
                              color: FtColors.otpSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: FtColors.progressStart.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    event.startingPriceLabel,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: FtColors.progressEnd,
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
}
