import 'package:flutter/material.dart';

import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';
import 'admin-subscription-plans-card.dart';

class AdminPlatformSettingsScreen extends StatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  State<AdminPlatformSettingsScreen> createState() =>
      _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState
    extends State<AdminPlatformSettingsScreen> {
  final _platformNameController = TextEditingController(text: 'FairTix');
  final _saleRateController = TextEditingController(text: '10');
  final _sessionTimeoutController = TextEditingController(text: '30');
  String _payoutSchedule = 'Monthly (1st of month)';
  bool _twoFactorRequired = true;
  bool _emailAlerts = true;
  bool _weeklyDigest = true;
  DateTime? _lastSavedAt;

  @override
  void dispose() {
    _platformNameController.dispose();
    _saleRateController.dispose();
    _sessionTimeoutController.dispose();
    super.dispose();
  }

  void _saveChanges(String section) {
    setState(() => _lastSavedAt = DateTime.now());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$section settings saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return AdminShell(
      active: AdminNavItem.platformSettings,
      title: 'Settings',
      body: _buildContent(isWide),
    );
  }

  Widget _buildContent(bool isWide) {
    final p = FairTixPalette.of(context);
    final general = _buildGeneralCard();
    final payment = _buildPaymentCard();
    final security = _buildSecurityCard();
    final notifications = _buildNotificationsCard();

    Widget stack(List<Widget> cards) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          cards[i],
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Platform Settings',
          subtitle: 'Manage global application rules and pricing structures.',
          actions: [
            if (_lastSavedAt != null)
              Text(
                'Last saved: ${formatAdminDateTime(_lastSavedAt!)}',
                style: orgText(p, size: 12, color: p.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 24),
        // Two balanced columns on wide screens; on narrow ones the cards
        // stack in their logical order.
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: stack([general, notifications])),
              const SizedBox(width: 20),
              Expanded(child: stack([payment, security])),
            ],
          )
        else
          stack([general, payment, security, notifications]),
        const SizedBox(height: 20),
        const AdminSubscriptionPlansCard(),
      ],
    );
  }

  Widget _buildGeneralCard() => _SettingsCard(
    icon: Icons.tune_rounded,
    title: 'General',
    subtitle: 'Configure platform name and logo.',
    footer: 'Changes take effect immediately.',
    onSave: () => _saveChanges('General'),
    children: [
      _fieldLabel('Platform Name', 'Displayed in headers and emails.'),
      _input(_platformNameController, italic: true),
      const SizedBox(height: 20),
      _fieldLabel('Logo', 'Upload a square PNG (min 512x512).'),
      Align(
        alignment: Alignment.centerLeft,
        child: AdminHeaderButton(
          icon: Icons.upload_outlined,
          label: 'Upload logo',
          onPressed: () => _saveChanges('Logo'),
        ),
      ),
    ],
  );

  Widget _buildPaymentCard() => _SettingsCard(
    icon: Icons.payments_outlined,
    title: 'Payment',
    subtitle: 'Configure fee percentages and payout schedule.',
    footer: 'Resale fee (all tiers): flat 5% of resale price.',
    onSave: () => _saveChanges('Payment'),
    children: [
      _fieldLabel(
        'Primary Sale Fee Rates',
        'Basic: 8% \u00B7 Standard: 9% \u00B7 Premium: 10% per ticket sold.',
      ),
      _input(
        _saleRateController,
        suffix: '%',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 20),
      _fieldLabel('Payout Schedule', 'When payouts are sent to organizers.'),
      DropdownButtonFormField<String>(
        initialValue: _payoutSchedule,
        dropdownColor: FairTixPalette.of(context).surface,
        items: const [
          DropdownMenuItem(
            value: 'Monthly (1st of month)',
            child: Text('Monthly (1st of month)'),
          ),
          DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
          DropdownMenuItem(
            value: 'After each event',
            child: Text('After each event'),
          ),
        ],
        onChanged: (value) =>
            setState(() => _payoutSchedule = value ?? _payoutSchedule),
        decoration: _inputDecoration(),
        style: orgText(
          FairTixPalette.of(context),
          size: 14,
          weight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildSecurityCard() => _SettingsCard(
    icon: Icons.shield_outlined,
    title: 'Security',
    subtitle: 'Control session timeout and 2FA requirements.',
    footer: 'This affects all administrator sessions.',
    footerDanger: true,
    onSave: () => _saveChanges('Security'),
    children: [
      _fieldLabel(
        'Session Timeout',
        'Minutes before requiring re-authentication.',
      ),
      _input(_sessionTimeoutController, keyboardType: TextInputType.number),
      const SizedBox(height: 16),
      _switchRow(
        '2FA Required',
        'Enforce two-factor authentication for all admins.',
        _twoFactorRequired,
        (value) => setState(() => _twoFactorRequired = value),
      ),
    ],
  );

  Widget _buildNotificationsCard() => _SettingsCard(
    icon: Icons.notifications_none,
    title: 'Notifications',
    subtitle: 'Control email notifications for system events.',
    onSave: () => _saveChanges('Notification'),
    children: [
      _switchRow(
        'Email Alerts',
        'Send emails for fraud alerts and system issues.',
        _emailAlerts,
        (value) => setState(() => _emailAlerts = value),
      ),
      const SizedBox(height: 16),
      _switchRow(
        'Weekly Digest',
        'Send a weekly summary of revenue and activity.',
        _weeklyDigest,
        (value) => setState(() => _weeklyDigest = value),
      ),
    ],
  );

  Widget _fieldLabel(String title, String description) {
    final p = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: orgText(p, size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            description,
            style: orgText(p, size: 12, color: p.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _input(
    TextEditingController controller, {
    String? suffix,
    bool italic = false,
    TextInputType? keyboardType,
  }) {
    final p = FairTixPalette.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: p.accentLabel,
      textAlign: suffix == null ? TextAlign.left : TextAlign.right,
      style: orgText(
        p,
        size: 14,
        weight: FontWeight.w600,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
      decoration: _inputDecoration(suffix: suffix),
    );
  }

  InputDecoration _inputDecoration({String? suffix}) {
    final p = FairTixPalette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      isDense: true,
      suffixText: suffix,
      suffixStyle: orgText(p, size: 14, color: p.textSecondary),
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(p.accentLabel),
    );
  }

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final p = FairTixPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: orgText(p, size: 14, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: orgText(
                  p,
                  size: 12,
                  color: p.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: p.primary,
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? footer;
  final bool footerDanger;
  final VoidCallback onSave;
  final List<Widget> children;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSave,
    required this.children,
    this.footer,
    this.footerDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: FairTixPalette.buttonGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: orgText(p, size: 16, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  subtitle,
                  style: orgText(p, size: 13, color: p.textSecondary),
                ),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            child: Row(
              children: [
                if (footer != null)
                  Expanded(
                    child: Text(
                      footer!,
                      style: orgText(
                        p,
                        size: 12,
                        color: footerDanger ? p.danger : p.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                AdminHeaderButton(
                  label: 'Save Changes',
                  filled: true,
                  onPressed: onSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
