import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/support_contact.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_resale_ui.dart';
import '../../widgets/ft_subpage_ui.dart';
import 'terms_privacy_screen.dart';

/// "Help & Support" screen — a short FAQ, the support email, and the Terms &
/// Privacy Policy. Dark design that follows the Light / Dark switch.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const _faqs = [
    (
      question: 'How does resale work?',
      answer:
          'You can list a ticket for 50%–100% of the price you paid. A verified buyer pays the '
          'listing price and gets a new QR code, so your old QR stops working. FairTix keeps a flat 5% '
          'from what you receive; buyers pay no extra fees. Listings close automatically 24 hours before '
          'the event, and a ticket that doesn’t sell comes back to you.',
    ),
    (
      question: 'When do I get my money?',
      answer:
          'The buyer’s payment is held until their new QR code has been issued. After that, your '
          'payout (the listing price minus the 5% resale fee) is released to you. You can follow it under '
          'Profile › Transactions.',
    ),
    (
      question: 'My QR code isn’t working',
      answer:
          'Open the ticket from My Tickets in the account that owns it, raise your screen brightness, and '
          'keep the whole code visible. A ticket that was resold or already scanned won’t scan again, '
          'and the previous owner’s QR stops working once it is resold. If it still fails, email us '
          'with your ticket reference.',
    ),
    (
      question: 'Why is my account pending?',
      answer:
          'FairTix checks every new account’s ID and selfie before it can buy or resell tickets. You '
          'can browse events while you wait, and you’ll get a notification once an admin approves '
          'your account. If it was rejected, email us.',
    ),
    (
      question: 'How do refunds work?',
      answer:
          'Refunds are issued automatically, only when an organizer cancels a published event, and they go '
          'to whoever holds the ticket at that time. There are no refunds for a change of mind or for not '
          'attending.',
    ),
  ];

  int? _openIndex;

  Future<void> _emailSupport() async {
    final opened = await FairTixSupport.compose(subject: 'FairTix support request');
    if (opened || !mounted) return;
    await FairTixSupport.copyEmail();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No email app found. The address was copied.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    return FtSubpageScaffold(
      title: 'Help & Support',
      onBack: () => Navigator.of(context).maybePop(),
      followTheme: true,
      body: [
        FtSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              for (var i = 0; i < _faqs.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: t.divider),
                _FaqRow(
                  question: _faqs[i].question,
                  answer: _faqs[i].answer,
                  open: _openIndex == i,
                  onTap: () => setState(() => _openIndex = _openIndex == i ? null : i),
                ),
              ],
            ],
          ),
        ),
        if (FairTixSupport.isAvailable) ...[
          const SizedBox(height: 18),
          FtSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Still need help?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: t.titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Email us and include your ticket or transaction reference.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    height: 1.4,
                    color: t.subtitleColor,
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  button: true,
                  label: 'Email ${FairTixSupport.email}',
                  excludeSemantics: true,
                  child: Material(
                    color: t.fieldFill,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(color: t.fieldBorder),
                    ),
                    child: InkWell(
                      customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      onTap: _emailSupport,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                FairTixSupport.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  color: t.titleColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.mail_outline_rounded, size: 22, color: t.activeAccent),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        FtSurfaceCard(
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Terms & Privacy Policy',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: t.titleColor,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 26, color: t.secondaryText),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            'FairTix v1.0.0 • Capstone Prototype Build',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: t.subtitleColor),
          ),
        ),
      ],
    );
  }
}

/// One FAQ line: tap to show or hide the answer.
class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.question,
    required this.answer,
    required this.open,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 200);
    return Semantics(
      button: true,
      expanded: open,
      label: question,
      excludeSemantics: true,
      onTapHint: open ? 'Hide the answer' : 'Show the answer',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: t.titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: duration,
                    child: Icon(Icons.chevron_right_rounded, size: 28, color: t.secondaryText),
                  ),
                ],
              ),
              AnimatedSize(
                duration: duration,
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12, right: 8),
                        child: Text(
                          answer,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            height: 1.5,
                            color: t.subtitleColor,
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
