import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtBackButton;
import '../../widgets/ft_registration_ui.dart' show FtEntrance;

/// Terms of Use & Privacy Policy summary for the FairTix prototype, in two
/// tabs. Content reflects the system's own documented rules (resale
/// ceiling/floor, refund policy, RA 10173 compliance) rather than a legally
/// reviewed policy document; the wording is the same as before, only grouped
/// under the Terms and Privacy tabs.
/// TODO: replace with counsel-reviewed Terms & Privacy copy before any
/// real-money production deployment.
class TermsPrivacyScreen extends StatefulWidget {
  const TermsPrivacyScreen({super.key, this.initialTab = 0});

  /// 0 = Terms, 1 = Privacy. Lets "Privacy Policy" links open the right tab.
  final int initialTab;

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

typedef _Section = ({String title, List<String> paragraphs});

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen> {
  static const List<_Section> _terms = [
    (
      title: 'Using FairTix',
      paragraphs: [
        'FairTix is an academic capstone prototype. Payments run through PayMongo\u2019s Sandbox '
            '(test-mode) environment using test GCash, Maya, and card numbers \u2014 no real money is ever '
            'processed, and this build is not intended for commercial use.',
      ],
    ),
    (
      title: 'Tickets and resale',
      paragraphs: [
        'When you buy a ticket, your payment is processed securely through PayMongo. Your ticket and QR '
            'code are issued right away, and payments to organizers and sellers are handled automatically by '
            'FairTix\u2019s internal payment system.',
        'Tickets may only be resold through FairTix, at a price between 50% and 100% of the original '
            'purchase price. This range is enforced automatically to keep resale fair and discourage scalping. '
            'Active listings close 24 hours before an event starts, and any unsold ticket is returned to its '
            'owner.',
      ],
    ),
    (
      title: 'Refunds',
      paragraphs: [
        'Refunds are issued automatically, and only when an event organizer cancels a published event. '
            'They are not issued for a change of mind or a failed resale attempt. If a ticket was resold '
            'before a cancellation, the refund goes to whoever holds it at the time of cancellation.',
      ],
    ),
    (
      title: 'Your data',
      paragraphs: [
        'How we handle your ID, selfie, and account details is explained in the Privacy tab.',
      ],
    ),
  ];

  static const List<_Section> _privacy = [
    (
      title: 'Identity verification',
      paragraphs: [
        'Creating an account requires email OTP confirmation and a valid government- or school-issued '
            'ID with a live selfie for facial comparison. This is used only to confirm you\u2019re a real, unique '
            'person and to prevent one individual from holding multiple accounts to bypass purchase limits. '
            'Once verified, your name and contact details are locked to your ID and can only be changed by '
            'contacting support.',
      ],
    ),
    (
      title: 'What we collect and why',
      paragraphs: [
        'Your uploaded ID, selfie, and account details are collected solely to verify your identity and '
            'secure your tickets, handled in line with the Data Privacy Act of 2012 (Republic Act No. 10173).',
      ],
    ),
    (
      title: 'How it\u2019s protected',
      paragraphs: [
        'This data is encrypted, accessible only to automated verification processes and authorized '
            'administrators, and is not shared with third parties beyond what\u2019s needed to process your '
            'transactions.',
      ],
    ),
  ];

  late int _tab = widget.initialTab.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final sections = _tab == 0 ? _terms : _privacy;
    final t = FtAuthTheme.live(context);

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.overlayStyle,
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: FtAuthBackground(
          theme: t,
          child: SafeArea(
            child: FtEntrance(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FtBackButton(
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              'Terms & Privacy',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: t.titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Tabs(
                      selected: _tab,
                      labels: const ['Terms', 'Privacy'],
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      child: _PolicyCard(key: ValueKey(_tab), sections: sections),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Last reviewed: July 2026',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: t.secondaryText,
                        ),
                      ),
                    ),
                  ],
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

/// Two-segment switch with a purple pill that slides under the chosen label.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.labels, required this.onChanged});

  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 220);

    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surfaceFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: selected == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: FtColors.progressStart,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: FtColors.glow.withValues(alpha: t.glowAlpha),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: labels[i],
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: i == selected ? Colors.white : t.secondaryText,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({super.key, required this.sections});

  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: t.isDark ? t.surfaceFill.withValues(alpha: 0.75) : t.surfaceFill,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 22),
            Semantics(
              header: true,
              child: Text(
                '${i + 1}. ${sections[i].title}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: t.titleColor,
                ),
              ),
            ),
            for (final paragraph in sections[i].paragraphs) ...[
              const SizedBox(height: 8),
              Text(
                paragraph,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  height: 1.55,
                  color: t.secondaryText,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
