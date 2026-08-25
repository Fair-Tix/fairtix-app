import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/purple_header_bar.dart';
import 'simple_placeholder_screen.dart';
import 'terms_privacy_screen.dart';

/// "Help & Support" screen — FAQ, and entry points for contacting
/// support, reporting a problem, and reading the Terms & Privacy Policy.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    (
      question: 'Why do I need to verify my ID?',
      answer:
          'FairTix links every ticket to a verified account to prevent duplicate registrations and keep '
          'resale limited to genuine buyers. Verification requires a one-time email code, a valid ID, and '
          'a quick live selfie \u2014 after that, your name and contact details are locked to protect your account.',
    ),
    (
      question: 'How does resale pricing work?',
      answer:
          'You can only resell a ticket at or below its original purchase price, down to a floor of 50% of '
          'that price. This keeps resale fair and prevents scalping, while still giving you flexibility if '
          'you can no longer attend.',
    ),
    (
      question: 'What if I don\u2019t attend the event?',
      answer:
          'Your ticket simply goes unused \u2014 there\u2019s no refund for not showing up, since a refund is only '
          'issued if the organizer cancels the event.',
    ),
    (
      question: 'How do refunds work if an event is canceled?',
      answer:
          'Refunds are issued automatically, only when an organizer cancels a published event. If your '
          'ticket was resold before the cancellation, the refund goes to whoever holds it at the time of '
          'cancellation, not the original buyer. Refunds are not issued for a change of mind.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Help & Support',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: 'Frequently Asked Questions',
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionPanelList.radio(
                  elevation: 0,
                  expandedHeaderPadding: EdgeInsets.zero,
                  materialGapSize: 0,
                  children: _faqs
                      .map(
                        (faq) => ExpansionPanelRadio(
                          value: faq.question,
                          canTapOnHeader: true,
                          backgroundColor: Colors.transparent,
                          headerBuilder: (context, isExpanded) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              faq.question,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                          ),
                          body: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              faq.answer,
                              style: AppTextStyles.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Get Help',
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.support_agent_rounded,
                    label: 'CONTACT SUPPORT',
                    value: 'Message the FairTix Team',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SimplePlaceholderScreen(
                          title: 'Contact Support',
                          icon: Icons.support_agent_rounded,
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.inputBorderLight, height: 28),
                  _NavRow(
                    icon: Icons.flag_outlined,
                    label: 'REPORT A PROBLEM',
                    value: 'Report Fraud or a Bug',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SimplePlaceholderScreen(
                          title: 'Report a Problem',
                          icon: Icons.flag_outlined,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Legal',
              child: _NavRow(
                icon: Icons.description_outlined,
                label: 'TERMS & PRIVACY POLICY',
                value: 'Terms of Use & Privacy Policy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'FairTix v1.0.0 \u2022 Capstone Prototype Build',
                style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accentPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.cardLabel),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
        ],
      ),
    );
  }
}
