import 'package:flutter/material.dart';

import '../../models/organizer.dart';
import '../../services/organizer_auth_service.dart';
import '../../services/organizer_session.dart';
import '../../services/support_contact.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_account_ui.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-document-upload.dart';
import 'organizer-scaffold.dart';

/// Organizer Profile (Mahilum design): who the account is, whether it is
/// verified (and what that means), and which documents are on file.
/// Sign-in security (change password) lives on the Settings page, and
/// subscription, appearance and notification preferences live on their own
/// pages in the profile menu.
///
/// Organization name, organizer name and email are tied to the organizer's
/// verification documents, so they are read-only here; the page says how to
/// ask FairTix for a correction.
class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({super.key});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Verification status and documents can change on the server (an admin
  /// approves, a document finishes uploading), so re-read them when the page
  /// opens. Keeps the session's account if the refresh fails.
  Future<void> _refresh() async {
    await OrganizerAuthService.instance.refreshAccount();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final wide = MediaQuery.of(context).size.width >= 1000;
    final account = OrganizerSession.instance.account;

    final left = _identityColumn(context, p, account);
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _detailsCard(context, p, account),
        const SizedBox(height: 24),
        _verificationCard(context, p, account),
      ],
    );

    return OrganizerScaffold(
      pageTitle: 'Profile',
      activeItem: OrganizerNavItem.profile,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrganizerPageHeader(
            title: 'Profile',
            subtitle: 'Your organization and verification.',
          ),
          const SizedBox(height: 24),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 8, child: right),
              ],
            )
          else ...[left, const SizedBox(height: 24), right],
        ],
      ),
    );
  }

  // --- identity ------------------------------------------------------------

  Widget _identityColumn(
    BuildContext context,
    FairTixPalette p,
    OrganizerAccount? account,
  ) {
    final (label, tone, icon) = _statusOf(account);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrganizerCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FairTixPalette.buttonGradient,
                ),
                alignment: Alignment.center,
                child: Text(
                  account?.avatarInitial ?? '?',
                  style: orgText(
                    p,
                    size: 48,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                account?.organizationName ?? 'Organizer',
                textAlign: TextAlign.center,
                style: orgText(p, size: 24, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                account?.email ?? '',
                textAlign: TextAlign.center,
                style: orgText(
                  p,
                  size: 15,
                  weight: FontWeight.w600,
                  color: p.accentLabel,
                ),
              ),
              const SizedBox(height: 18),
              OrganizerPill(label: label, tone: tone, icon: icon),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _LogOutButton(onTap: () => confirmOrganizerLogOut(context)),
      ],
    );
  }

  (String, OrganizerTone, IconData) _statusOf(OrganizerAccount? account) {
    if (account == null || account.idVerificationStatus == 'pending') {
      return ('Pending approval', OrganizerTone.warning, Icons.schedule_rounded);
    }
    if (account.isApproved) {
      return ('Verified organizer', OrganizerTone.success, Icons.check_rounded);
    }
    return (
      'Application rejected',
      OrganizerTone.danger,
      Icons.close_rounded,
    );
  }

  // --- details -------------------------------------------------------------

  Widget _detailsCard(
    BuildContext context,
    FairTixPalette p,
    OrganizerAccount? account,
  ) {
    return OrganizerSectionCard(
      title: 'Organization details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrganizerDetailRow(
            label: 'Organization name',
            value: account?.organizationName ?? '',
            locked: true,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final name = OrganizerDetailRow(
                label: 'Organizer name',
                value: account?.fullName ?? '',
                locked: true,
              );
              final email = OrganizerDetailRow(
                label: 'Email address',
                value: account?.email ?? '',
                locked: true,
              );
              if (c.maxWidth < 520) {
                return Column(
                  children: [name, const SizedBox(height: 18), email],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: name),
                  const SizedBox(width: 20),
                  Expanded(child: email),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          OrganizerNote(
            icon: Icons.lock_outline_rounded,
            text: FairTixSupport.isAvailable
                ? 'These details are tied to your verified identity and '
                      'organization documents, so they can\u2019t be edited '
                      'here. If something is wrong, ask FairTix to correct it.'
                : 'These details are tied to your verified identity and '
                      'organization documents, so they can\u2019t be edited '
                      'here. If something is wrong, contact FairTix support to '
                      'have it corrected.',
            action: FairTixSupport.isAvailable
                ? OrganizerTextLink(
                    label: 'Request a correction',
                    size: 14,
                    onTap: () => _requestCorrection(context, account),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _requestCorrection(
    BuildContext context,
    OrganizerAccount? account,
  ) async {
    final opened = await FairTixSupport.compose(
      subject: 'Correction request for my organizer account',
      body:
          'Organization: ${account?.organizationName ?? ''}\n'
          'Account email: ${account?.email ?? ''}\n\n'
          'What needs to be corrected, and the correct details:\n',
    );
    if (opened || !context.mounted) return;
    await FairTixSupport.copyEmail();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open your email app. The FairTix support address was '
          'copied instead.',
        ),
      ),
    );
  }

  // --- verification --------------------------------------------------------

  Widget _verificationCard(
    BuildContext context,
    FairTixPalette p,
    OrganizerAccount? account,
  ) {
    final (label, tone, icon) = _statusOf(account);
    final docs = account?.hasSubmittedDocuments ?? false;

    final String guidance;
    if (account != null && account.isApproved) {
      guidance =
          'Your organizer account is verified. You can create and publish '
          'events for as long as your subscription is active.';
    } else if (account != null && account.idVerificationStatus == 'rejected') {
      guidance =
          'Your application wasn\u2019t approved. Contact FairTix support to '
          'find out why and what you can do next.';
    } else {
      guidance = docs
          ? 'Both documents are on file and an admin is reviewing your '
                'application. You\u2019ll be notified once a decision is '
                'made; event features unlock after approval.'
          : 'Upload the missing document(s) so an admin can review your '
                'application. Event features unlock after approval.';
    }

    return OrganizerSectionCard(
      title: 'Verification',
      trailing: OrganizerPill(label: label, tone: tone, icon: icon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            guidance,
            style: orgText(p, size: 14.5, color: p.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Submitted documents',
            style: orgText(p, size: 14, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          _DocRow(
            label: 'Government / school ID',
            submitted: account?.venueProofUrl != null,
          ),
          _DocRow(
            label: 'Proof of organization',
            submitted: account?.eventPermitUrl != null,
          ),
          if (account != null && !docs) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 220,
                child: OrganizerPrimaryButton(
                  label: 'Upload missing documents',
                  height: 44,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrganizerDocumentUploadScreen(account: account),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.label, required this.submitted});

  final String label;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 20, color: p.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: orgText(p, size: 15, weight: FontWeight.w600)),
          ),
          OrganizerPill(
            label: submitted ? 'Submitted' : 'Missing',
            tone: submitted ? OrganizerTone.success : OrganizerTone.warning,
            icon: submitted ? Icons.check_rounded : Icons.error_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(18);

    return Material(
      color: p.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.danger.withValues(alpha: 0.7)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, size: 20, color: p.danger),
              const SizedBox(width: 12),
              Text(
                'Log Out',
                style: orgText(
                  p,
                  size: 16,
                  weight: FontWeight.w700,
                  color: p.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
