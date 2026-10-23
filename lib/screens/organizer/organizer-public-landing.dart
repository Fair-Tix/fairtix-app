import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/fairtix_palette.dart';
import '../../widgets/fairtix_mark.dart';
import '../../widgets/theme_mode_switch.dart';
import '../../widgets/top_glow_background.dart';
import '../admin/admin-login.dart';
import 'organizer-login.dart';
import 'organizer-register.dart';

/// Public organizer landing page (new design): top bar, hero, how it works,
/// ticket controls, dashboard preview, getting started, pricing, FAQ, final
/// call to action and footer. Reached from the splash screen.
///
/// All colors come from [FairTixPalette], so the page follows the Light / Dark
/// switch in the top bar (the design file is the Dark version).
class OrganizerPublicLandingScreen extends StatefulWidget {
  const OrganizerPublicLandingScreen({super.key});

  @override
  State<OrganizerPublicLandingScreen> createState() =>
      _OrganizerPublicLandingScreenState();
}

class _OrganizerPublicLandingScreenState
    extends State<OrganizerPublicLandingScreen> {
  final GlobalKey _pricingKey = GlobalKey();

  static const List<({IconData icon, String title, String body})> _steps = [
    (
      icon: Icons.event_outlined,
      title: 'Create your event',
      body: 'Add event details, dates, venue, description, banner, and '
          'supporting documents.',
    ),
    (
      icon: Icons.confirmation_number_outlined,
      title: 'Set up ticket types',
      body: 'Create ticket tiers, choose prices, and set available '
          'quantities.',
    ),
    (
      icon: Icons.bar_chart_rounded,
      title: 'Track ticket sales',
      body: 'Review sales and event activity from your organizer dashboard.',
    ),
    (
      icon: Icons.qr_code_scanner_rounded,
      title: 'Scan tickets at the door',
      body: 'Use FairTix scanning tools to check QR tickets at entry.',
    ),
  ];

  static const List<({IconData icon, String title, String body})> _controls = [
    (
      icon: Icons.verified_user_outlined,
      title: 'QR ticket validation',
      body: 'Tickets are checked at entry and cannot be reused once scanned.',
    ),
    (
      icon: Icons.attach_money_rounded,
      title: 'Resale price limits',
      body: 'In-app resale is held between 50% and 100% of the original '
          'price.',
    ),
    (
      icon: Icons.badge_outlined,
      title: 'Buyer identity verification',
      body: 'Accounts go through ID verification before buying tickets.',
    ),
    (
      icon: Icons.lock_outline_rounded,
      title: 'Escrow and payout timing',
      body: 'Payments are held, then released after scanning or event end.',
    ),
  ];

  static const List<String> _getStarted = [
    'Submit an organizer application',
    'Complete any required document uploads',
    'Wait for the application review',
    'After approval, choose a plan and set up an event',
  ];

  static const List<({String q, String a})> _faqs = [
    (
      q: 'What is FairTix?',
      a: 'FairTix gives event organizers one place to publish events, set up '
          'ticket types, track sales, and scan tickets at the door.',
    ),
    (
      q: 'Who can apply for an organizer account?',
      a: 'Event organizers can apply by submitting an organizer application. '
          'Organizer tools open up after your application is approved.',
    ),
    (
      q: 'What documents are required?',
      a: 'After you submit your application, you will be asked to upload any '
          'required documents. The upload step shows exactly what is needed.',
    ),
    (
      q: 'What happens during application review?',
      a: 'Your application and documents are reviewed before approval. Until '
          'then, your organizer dashboard is browse-only and event tools '
          'stay locked.',
    ),
    (
      q: 'When can I create events?',
      a: 'Once your application is approved and, where applicable, you have '
          'an active plan. After approval, choose a plan and set up an '
          'event.',
    ),
    (
      q: 'How do QR scanning and ticket validation work?',
      a: 'Tickets carry QR codes that are checked at entry using FairTix '
          'scanning tools. A ticket cannot be reused once it has been '
          'scanned.',
    ),
    (
      q: 'How do payouts work?',
      a: 'Payments are held in escrow, then released after scanning or '
          'event end.',
    ),
  ];

  void _scrollToPricing() {
    final ctx = _pricingKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final altBand = p.surface.withValues(alpha: p.isDark ? 0.35 : 0.55);

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          const TopGlowBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final l = _Layout.of(constraints.maxWidth);

                return Column(
                  children: [
                    _StickyNav(layout: l),
                    Expanded(
                      child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top bar + hero
                      _Band(
                        layout: l,
                        top: 16,
                        bottom: l.vpad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: l.wide ? 40 : 16),
                            _Hero(layout: l),
                          ],
                        ),
                      ),

                      // How it works
                      _Band(
                        layout: l,
                        child: Column(
                          children: [
                            _SectionHeading(
                              layout: l,
                              eyebrow: 'HOW IT WORKS',
                              title: 'Everything you need to manage event '
                                  'tickets',
                            ),
                            const SizedBox(height: 40),
                            _CardGrid(
                              columns: l.columns4,
                              children: [
                                for (final s in _steps)
                                  _InfoCard(
                                    icon: s.icon,
                                    title: s.title,
                                    body: s.body,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Ticket controls
                      _Band(
                        layout: l,
                        color: altBand,
                        child: _TicketControls(layout: l, controls: _controls),
                      ),

                      // Dashboard preview
                      _Band(
                        layout: l,
                        child: Column(
                          children: [
                            _SectionHeading(
                              layout: l,
                              eyebrow: 'DASHBOARD',
                              title: 'Keep your event operations in one place',
                            ),
                            const SizedBox(height: 36),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: const _ImagePlaceholder(
                                aspect: 2,
                                reveal: true,
                                label: 'Dashboard screenshot placeholder',
                                hint: 'Replace with real dashboard '
                                    'screenshot \u00B7 16:8',
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _RevealPill(label: 'Events', delayMs: 0),
                                _RevealPill(label: 'Ticket tiers', delayMs: 60),
                                _RevealPill(label: 'Sales', delayMs: 120),
                                _RevealPill(label: 'Scanner sessions', delayMs: 180),
                                _RevealPill(label: 'Reports', delayMs: 240),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Getting started
                      _Band(
                        layout: l,
                        color: altBand,
                        child: Column(
                          children: [
                            _SectionHeading(
                              layout: l,
                              eyebrow: 'GETTING STARTED',
                              title: 'Get started as a FairTix organizer',
                              subtitle: 'Organizer tools open up after '
                                  'approval and, where applicable, an active '
                                  'plan.',
                            ),
                            const SizedBox(height: 36),
                            _CardGrid(
                              columns: l.columns4,
                              children: [
                                for (var i = 0; i < _getStarted.length; i++)
                                  _StepCard(
                                    number: i + 1,
                                    title: _getStarted[i],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Pricing
                      _Band(
                        key: _pricingKey,
                        layout: l,
                        child: Column(
                          children: [
                            _SectionHeading(
                              layout: l,
                              eyebrow: 'PRICING',
                              title: 'Plans for your event operations',
                            ),
                            const SizedBox(height: 36),
                            _CardGrid(
                              columns: l.wide ? 3 : 1,
                              children: const [
                                _PlanCard(name: 'Basic', price: '\u20B1299'),
                                _PlanCard(name: 'Standard'),
                                _PlanCard(name: 'Premium'),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // FAQ
                      _Band(
                        layout: l,
                        top: 24,
                        child: Column(
                          children: [
                            _SectionHeading(
                              layout: l,
                              title: 'Questions organizers often ask',
                            ),
                            const SizedBox(height: 32),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Column(
                                children: [
                                  for (final f in _faqs) ...[
                                    _Reveal(
                                      offset: 20,
                                      child: _FaqItem(question: f.q, answer: f.a),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Final call to action
                      _Band(
                        layout: l,
                        top: 24,
                        child: _Reveal(child: _CtaBanner(layout: l)),
                      ),

                      // Footer
                      _Band(
                        layout: l,
                        top: 40,
                        bottom: 28,
                        border: true,
                        child: _Reveal(
                          offset: 16,
                          child: _Footer(layout: l, onPricing: _scrollToPricing),
                        ),
                      ),
                    ],
                  ),
                  )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------

/// Navigation bar pinned to the top of the page. The page scrolls beneath it,
/// so it stays visible; a soft blur keeps content readable behind it.
class _StickyNav extends StatelessWidget {
  const _StickyNav({required this.layout});

  final _Layout layout;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: p.background.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(color: p.border.withValues(alpha: 0.6)),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: layout.pad, vertical: 10),
          child: Center(
            child: SizedBox(
              width: layout.contentWidth,
              child: _Reveal(
                offset: 0,
                delay: const Duration(milliseconds: 150),
                child: _TopBar(showButtons: layout.medium),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades and slides its child up the first time it scrolls into view (or
/// right away if it is already on screen). [delay] staggers neighbours.
/// Does nothing when the system asks for reduced motion.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 28,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _curve =
      _c.drive(CurveTween(curve: Curves.easeOutCubic));

  ScrollPosition? _position;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _position?.removeListener(_check);
      _position = next;
      _position?.addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_started || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final viewport = MediaQuery.sizeOf(context).height;
    if (top < viewport * 0.92) _start();
  }

  Future<void> _start() async {
    _started = true;
    _position?.removeListener(_check);
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (mounted) _c.forward();
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: child,
        ),
      ),
    );
  }
}

class _Layout {
  const _Layout._(this.width, this.wide, this.medium, this.pad);

  factory _Layout.of(double width) {
    final wide = width >= 1000;
    final medium = width >= 640;
    return _Layout._(width, wide, medium, wide ? 40.0 : (medium ? 28.0 : 20.0));
  }

  static const double maxContentWidth = 1280;

  final double width;
  final bool wide;
  final bool medium;
  final double pad;

  double get contentWidth =>
      (width - pad * 2).clamp(0.0, maxContentWidth).toDouble();

  /// Vertical padding of a normal section.
  double get vpad => wide ? 88 : 56;

  int get columns4 => wide ? 4 : (medium ? 2 : 1);

  double get titleSize => wide ? 32 : (medium ? 28 : 24);
}

/// A full-width section. [color] paints the background band; the content is
/// centered and capped at [_Layout.maxContentWidth].
class _Band extends StatelessWidget {
  const _Band({
    super.key,
    required this.layout,
    required this.child,
    this.color,
    this.top,
    this.bottom,
    this.border = false,
  });

  final _Layout layout;
  final Widget child;
  final Color? color;
  final double? top;
  final double? bottom;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        border: border ? Border(top: BorderSide(color: p.border)) : null,
      ),
      padding: EdgeInsets.fromLTRB(
        layout.pad,
        top ?? layout.vpad,
        layout.pad,
        bottom ?? layout.vpad,
      ),
      child: Center(
        child: SizedBox(width: layout.contentWidth, child: child),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.layout,
    required this.title,
    this.eyebrow,
    this.subtitle,
  });

  final _Layout layout;
  final String title;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return _Reveal(child: Column(
      children: [
        if (eyebrow != null) ...[
          _Eyebrow(eyebrow!),
          const SizedBox(height: 10),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -layout.titleSize * 0.025,
            height: 1.2,
            color: p.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                height: 1.6,
                color: p.textSecondary,
              ),
            ),
          ),
        ],
      ],
    ));
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.textAlign = TextAlign.center});

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Text(
      text,
      textAlign: textAlign,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: p.accentLabel,
      ),
    );
  }
}

/// Equal-height card grid with [columns] columns.
class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.columns,
    required this.children,
  });

  /// Space between cards, horizontally and vertically.
  static const double gap = 20;

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(i, math.min(i + columns, children.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(
                  child: j < slice.length
                      ? _Reveal(
                          delay: Duration(milliseconds: 90 * j),
                          offset: 24,
                          child: slice[j],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + columns < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

void _goToLogin(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const OrganizerLoginScreen()),
  );
}

void _goToRegister(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const OrganizerRegisterScreen()),
  );
}

void _goToAdmin(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
  );
}

// ---------------------------------------------------------------------------
// Top bar + hero
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showButtons});

  final bool showButtons;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const FairTixMark(width: 52),
          const SizedBox(width: 8),
          Text(
            'FairTix',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: p.textPrimary,
            ),
          ),
          const Spacer(),
          const ThemeModeSwitch(),
          if (showButtons) ...[
            const SizedBox(width: 16),
            _OutlinedButton(
              label: 'Log In',
              onPressed: () => _goToLogin(context),
            ),
            const SizedBox(width: 12),
            _GradientButton(
              label: 'Apply as an Organizer',
              onPressed: () => _goToRegister(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.layout});

  final _Layout layout;

  @override
  Widget build(BuildContext context) {
    final text = _Reveal(
      delay: const Duration(milliseconds: 300),
      child: _HeroText(layout: layout),
    );
    final visual = _Reveal(
      delay: const Duration(milliseconds: 450),
      offset: 40,
      child: const _ImagePlaceholder(
      aspect: 4 / 3,
      label: 'Organizer dashboard image placeholder',
      hint: 'Replace with screenshot \u00B7 4:3',
      glow: true,
    ),
    );

    if (layout.wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: text),
          const SizedBox(width: 64),
          Expanded(child: visual),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text,
        const SizedBox(height: 40),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: visual,
          ),
        ),
      ],
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.layout});

  final _Layout layout;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final size = layout.wide ? 56.0 : (layout.medium ? 46.0 : 34.0);
    final base = GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -size * 0.037,
      height: 1.1,
      color: p.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('EVENT TICKETING FOR ORGANIZERS',
            textAlign: TextAlign.start),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            style: base,
            children: [
              const TextSpan(text: 'Create your event.\n'),
              TextSpan(
                text: 'Sell tickets.',
                style: TextStyle(color: p.accentLabel),
              ),
              const TextSpan(text: ' Welcome your crowd.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'FairTix gives event organizers one place to publish events, set '
            'up ticket types, track sales, and scan tickets at the door.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              height: 1.6,
              color: p.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _GradientButton(
              label: 'Apply as an Organizer',
              onPressed: () => _goToRegister(context),
            ),
            _OutlinedButton(
              label: 'Log In',
              onPressed: () => _goToLogin(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Pill(label: 'QR ticket validation'),
            _Pill(label: 'Capped resale'),
            _Pill(label: 'Escrow payouts'),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ticket controls (text on the left, 2 x 2 cards on the right)
// ---------------------------------------------------------------------------

class _TicketControls extends StatelessWidget {
  const _TicketControls({required this.layout, required this.controls});

  final _Layout layout;
  final List<({IconData icon, String title, String body})> controls;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('TICKET CONTROLS', textAlign: TextAlign.start),
        const SizedBox(height: 12),
        Text(
          'A more controlled ticketing experience',
          style: GoogleFonts.plusJakartaSans(
            fontSize: layout.titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -layout.titleSize * 0.025,
            height: 1.2,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Controls built into the platform, so you spend less time '
            'policing tickets.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.6,
              color: p.textSecondary,
            ),
          ),
        ),
      ],
    );

    final grid = _CardGrid(
      columns: layout.medium ? 2 : 1,
      children: [
        for (final c in controls)
          _InfoCard(icon: c.icon, title: c.title, body: c.body),
      ],
    );

    if (layout.wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 4, child: _Reveal(child: intro)),
          const SizedBox(width: 48),
          Expanded(flex: 7, child: grid),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_Reveal(child: intro), const SizedBox(height: 32), grid],
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

BoxDecoration _cardDecoration(FairTixPalette p) => BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: p.border),
      boxShadow: p.isDark
          ? null
          : [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
    );

class _IconTile extends StatelessWidget {
  const _IconTile({this.icon, this.label});

  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: FairTixPalette.buttonGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: icon != null
          ? Icon(icon, size: 20, color: Colors.white)
          : Text(
              label ?? '',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(icon: icon),
          const SizedBox(height: 18),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.55,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(label: '$number'),
          const SizedBox(height: 18),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.name, this.price});

  final String name;

  /// When null, the card says pricing is shown in plan selection.
  final String? price;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (price != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ month',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: p.textSecondary,
                  ),
                ),
              ],
            )
          else
            Text(
              'Pricing in plan selection',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: p.accentLabel,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Full details shown when you choose a plan after approval.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.55,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.radius = 999});

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
      ),
    );
  }
}

/// Stand-in for a screenshot. Swap the child for an `Image.asset` once the
/// real screenshot is added to `assets/`.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    required this.aspect,
    required this.label,
    required this.hint,
    this.glow = false,
    this.reveal = false,
  });

  final double aspect;
  final String label;
  final String hint;
  final bool glow;

  /// Fade/slide in when scrolled into view.
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final box = _ImagePlaceholderBox(
      aspect: aspect,
      label: label,
      hint: hint,
      glow: glow,
    );
    return reveal ? _Reveal(offset: 36, child: box) : box;
  }
}

class _RevealPill extends StatelessWidget {
  const _RevealPill({required this.label, required this.delayMs});

  final String label;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return _Reveal(
      delay: Duration(milliseconds: delayMs),
      offset: 14,
      child: _Pill(label: label, radius: 8),
    );
  }
}

class _ImagePlaceholderBox extends StatelessWidget {
  const _ImagePlaceholderBox({
    required this.aspect,
    required this.label,
    required this.hint,
    this.glow = false,
  });

  final double aspect;
  final String label;
  final String hint;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return AspectRatio(
      aspectRatio: aspect,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(
              color: p.primary.withValues(
                alpha: glow ? (p.isDark ? 0.28 : 0.16) : (p.isDark ? 0.16 : 0.08),
              ),
              blurRadius: glow ? 70 : 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, size: 20, color: p.textSecondary),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAQ
// ---------------------------------------------------------------------------

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(12);

    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          widget.answer,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            height: 1.6,
                            color: p.textSecondary,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Final call to action
// ---------------------------------------------------------------------------

class _CtaBanner extends StatelessWidget {
  const _CtaBanner({required this.layout});

  final _Layout layout;

  @override
  Widget build(BuildContext context) {
    final titleSize = layout.wide ? 32.0 : (layout.medium ? 26.0 : 22.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: layout.medium ? 40 : 24,
        vertical: layout.medium ? 56 : 40,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B35D8), Color(0xFF4A1FA0)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            'Ready to ticket your next event with FairTix?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -titleSize * 0.025,
              height: 1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Apply for an organizer account to start setting up your events '
            'and tickets.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _CtaButton(
                label: 'Apply as an Organizer',
                filled: true,
                onPressed: () => _goToRegister(context),
              ),
              _CtaButton(
                label: 'Log In',
                filled: false,
                onPressed: () => _goToLogin(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);

    return Material(
      color: filled ? Colors.white : Colors.transparent,
      borderRadius: radius,
      child: Ink(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.55)),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: filled ? const Color(0xFF4A1FA0) : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer({required this.layout, required this.onPricing});

  final _Layout layout;
  final VoidCallback onPricing;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FairTixMark(width: 44),
            const SizedBox(width: 8),
            Text(
              'FairTix',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'Event ticketing tools for organizers\u2014from event setup to '
            'ticket scanning.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.6,
              color: p.textSecondary,
            ),
          ),
        ),
      ],
    );

    // TODO: point Help & Support, Contact, Terms and Privacy at their screens.
    final columns = <Widget>[
      _FooterColumn(
        title: 'ORGANIZERS',
        links: [
          (label: 'Apply', onTap: () => _goToRegister(context)),
          (label: 'Log In', onTap: () => _goToLogin(context)),
          (label: 'Pricing', onTap: onPricing),
        ],
      ),
      const _FooterColumn(
        title: 'SUPPORT',
        links: [
          (label: 'Help & Support', onTap: null),
          (label: 'Contact', onTap: null),
        ],
      ),
      const _FooterColumn(
        title: 'LEGAL',
        links: [
          (label: 'Terms', onTap: null),
          (label: 'Privacy', onTap: null),
        ],
      ),
    ];

    final top = layout.wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: brand),
              for (final c in columns) Expanded(flex: 2, child: c),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              brand,
              const SizedBox(height: 28),
              Wrap(spacing: 48, runSpacing: 24, children: columns),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        const SizedBox(height: 36),
        Row(
          children: [
            Text(
              '\u00A9 2026 FairTix',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: p.textSecondary,
              ),
            ),
            const Spacer(),
            if (kIsWeb)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _goToAdmin(context),
                  child: Text(
                    'Admin Portal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<({String label, VoidCallback? onTap})> links;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Eyebrow(title, textAlign: TextAlign.start),
        const SizedBox(height: 10),
        for (final link in links)
          MouseRegion(
            cursor: link.onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: link.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  link.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons (44px tall, 14px labels, 12px corners)
// ---------------------------------------------------------------------------

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(12);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: p.primary.withValues(alpha: p.isDark ? 0.40 : 0.32),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            gradient: FairTixPalette.buttonGradient,
            borderRadius: radius,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(12);

    return Material(
      color: p.surface,
      borderRadius: radius,
      child: Ink(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: p.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
