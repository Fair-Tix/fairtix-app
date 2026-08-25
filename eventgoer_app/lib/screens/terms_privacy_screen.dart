import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/purple_header_bar.dart';

/// Static Terms of Use & Privacy Policy summary for the FairTix
/// prototype. Content reflects the system's own documented rules
/// (resale ceiling/floor, refund policy, RA 10173 compliance) rather
/// than a legally reviewed policy document.
/// TODO: replace with counsel-reviewed Terms & Privacy copy before any
/// real-money production deployment.
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  static const _sections = [
    (
      title: 'This Is a Prototype',
      body:
          'FairTix is an academic capstone prototype. Payments run through PayMongo\u2019s Sandbox '
          '(test-mode) environment using test GCash, Maya, and card numbers \u2014 no real money is ever '
          'processed, and this build is not intended for commercial use.',
    ),
    (
      title: 'Account & Identity Verification',
      body:
          'Creating an account requires email OTP confirmation and a valid government- or school-issued '
          'ID with a live selfie for facial comparison. This is used only to confirm you\u2019re a real, unique '
          'person and to prevent one individual from holding multiple accounts to bypass purchase limits. '
          'Once verified, your name and contact details are locked to your ID and can only be changed by '
          'contacting support.',
    ),
    (
      title: 'Ticket Purchases',
      body:
          'When you buy a ticket, your payment is processed securely through PayMongo. Your ticket and QR '
          'code are issued right away, and payments to organizers and sellers are handled automatically by '
          'FairTix\u2019s internal payment system.',
    ),
    (
      title: 'Resale Rules',
      body:
          'Tickets may only be resold through FairTix, at a price between 50% and 100% of the original '
          'purchase price. This range is enforced automatically to keep resale fair and discourage scalping. '
          'Active listings close 24 hours before an event starts, and any unsold ticket is returned to its '
          'owner.',
    ),
    (
      title: 'Refunds',
      body:
          'Refunds are issued automatically, and only when an event organizer cancels a published event. '
          'They are not issued for a change of mind or a failed resale attempt. If a ticket was resold '
          'before a cancellation, the refund goes to whoever holds it at the time of cancellation.',
    ),
    (
      title: 'Your Data & Privacy',
      body:
          'Your uploaded ID, selfie, and account details are collected solely to verify your identity and '
          'secure your tickets, handled in line with the Data Privacy Act of 2012 (Republic Act No. 10173). '
          'This data is encrypted, accessible only to automated verification processes and authorized '
          'administrators, and is not shared with third parties beyond what\u2019s needed to process your '
          'transactions.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Terms & Privacy Policy',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last reviewed: July 2026',
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 18),
            for (final section in _sections) ...[
              _PolicySection(title: section.title, body: section.body),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

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
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Text(body, style: AppTextStyles.bodyMuted.copyWith(fontSize: 13, height: 1.55)),
        ],
      ),
    );
  }
}
