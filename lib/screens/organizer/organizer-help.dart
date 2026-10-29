import 'package:flutter/material.dart';

import '../../services/organizer_session.dart';
import '../../services/support_contact.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_account_ui.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-scaffold.dart';

/// Organizer Help & Support: answers to common organizer questions and a way
/// to email FairTix.
///
/// Only reachable from the profile menu when [FairTixSupport.isAvailable], so
/// the menu never points at a page with no way to get help.
class OrganizerHelpScreen extends StatelessWidget {
  const OrganizerHelpScreen({super.key});

  static const _faqs = [
    (
      question: 'When do I get paid for my ticket sales?',
      answer:
          'Each sale is held in escrow: your share (the ticket price minus '
          'FairTix\u2019s platform fee) is released for payout the day after '
          'your event\u2019s last day, in Philippine time. Scanning tickets at '
          'the door does not release it. Multi-day events release one day at '
          'a time as each day ends. You can follow every peso under Escrow & '
          'Payouts.',
    ),
    (
      question: 'What happens if I cancel an event?',
      answer:
          'Buyers are refunded instead of the money being released to you. '
          'The refunded amount shows under Escrow & Payouts and in the refund '
          'note on that event in Analytics.',
    ),
    (
      question: 'Why was my event unpublished?',
      answer:
          'An admin unpublished it, and the reason is shown on the event and '
          'in your notifications. Open My Events, choose \u22EF on the event, '
          'and upload valid supporting documents before the deadline shown. '
          'An admin reviews them and republishes the event.',
    ),
    (
      question: 'How is the platform fee calculated?',
      answer:
          'FairTix keeps a percentage of each ticket sale, set by your '
          'subscription plan. Your net is the ticket price minus that fee. '
          'The rate for your plan is listed under Subscription.',
    ),
    (
      question: 'Why are some features locked?',
      answer:
          'Event features need both an approved organizer account and an '
          'active subscription. The banner at the top of each page tells '
          'you which one is missing: waiting for admin approval, an expired '
          'plan, or no plan yet.',
    ),
    (
      question: 'Why can\u2019t I change my name or email?',
      answer:
          'They\u2019re tied to the identity and organization documents you '
          'were verified with. If one is wrong, contact FairTix and ask for a '
          'correction.',
    ),
    (
      question: 'How do I scan tickets at the door?',
      answer:
          'Open My Events and choose Scan tickets on a published event. '
          'Scanning checks tickets in but does not affect when your payout '
          'is released.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerScaffold(
      pageTitle: 'Help & Support',
      activeItem: OrganizerNavItem.help,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrganizerPageHeader(
            title: 'Help & Support',
            subtitle: 'Answers to common questions, and how to reach FairTix.',
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OrganizerSectionCard(
                    title: 'Frequently asked questions',
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _faqs.length; i++)
                            _FaqTile(
                              question: _faqs[i].question,
                              answer: _faqs[i].answer,
                              topBorder: i > 0,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (FairTixSupport.isAvailable) ...[
                    const SizedBox(height: 24),
                    _contactCard(context, p),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(BuildContext context, FairTixPalette p) {
    return OrganizerSectionCard(
      title: 'Contact FairTix',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Can\u2019t find your answer? Email us and include your '
            'organization name and the event involved, if any.',
            style: orgText(p, size: 14.5, color: p.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.mail_outline_rounded, size: 20, color: p.accentLabel),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  FairTixSupport.email,
                  style: orgText(p, size: 15, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 170,
                child: OrganizerPrimaryButton(
                  label: 'Email support',
                  height: 44,
                  onPressed: () => _email(context),
                ),
              ),
              SizedBox(
                width: 150,
                child: OrganizerSecondaryButton(
                  label: 'Copy address',
                  height: 44,
                  onPressed: () => _copy(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _email(BuildContext context) async {
    final account = OrganizerSession.instance.account;
    final opened = await FairTixSupport.compose(
      subject: 'Organizer support request',
      body:
          'Organization: ${account?.organizationName ?? ''}\n'
          'Account email: ${account?.email ?? ''}\n\n'
          'How can we help?\n',
    );
    if (opened || !context.mounted) return;
    await _copy(context, openFailed: true);
  }

  Future<void> _copy(BuildContext context, {bool openFailed = false}) async {
    await FairTixSupport.copyEmail();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openFailed
              ? 'Could not open your email app. The support address was copied '
                    'instead.'
              : 'Support address copied.',
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
    required this.topBorder,
  });

  final String question;
  final String answer;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        border: topBorder ? Border(top: BorderSide(color: p.border)) : null,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16, right: 24),
        expandedAlignment: Alignment.centerLeft,
        iconColor: p.accentLabel,
        collapsedIconColor: p.textSecondary,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          question,
          style: orgText(p, size: 15, weight: FontWeight.w700, height: 1.4),
        ),
        children: [
          Text(
            answer,
            style: orgText(p, size: 14.5, color: p.textSecondary, height: 1.55),
          ),
        ],
      ),
    );
  }
}
