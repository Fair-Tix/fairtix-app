import 'package:flutter/material.dart';

import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';
import '../../services/admin_session.dart';
import '../../services/password_service.dart';
import '../../theme/fairtix_palette.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isSavingPassword = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSavingPassword = true);
    try {
      await PasswordService.instance.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on PasswordChangeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: FairTixPalette.of(context).danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return AdminShell(
      active: AdminNavItem.profile,
      title: 'Profile',
      body: _buildContent(isWide),
    );
  }

  Widget _buildContent(bool isWide) {
    final left = _buildIdentityCard();
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPasswordCard(),
        const SizedBox(height: 20),
        _buildActivityCard(),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminPageHeader(
          title: 'My Profile',
          subtitle: 'Your administrator account and sign-in security.',
        ),
        const SizedBox(height: 24),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: left),
              const SizedBox(width: 20),
              Expanded(flex: 6, child: right),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 20), right],
          ),
      ],
    );
  }

  Widget _buildIdentityCard() {
    final p = FairTixPalette.of(context);
    final currentEmail =
        AdminSession.instance.currentEmail ?? 'admin@fairtix.com';
    final sessionLabel = currentEmail.split('@').first.trim();
    final isSignedIn = AdminSession.instance.isSignedIn;

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: FairTixPalette.buttonGradient,
                boxShadow: [
                  BoxShadow(
                    color: p.primary.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                sessionLabel.isNotEmpty ? sessionLabel[0].toUpperCase() : 'A',
                style: orgText(
                  p,
                  size: 28,
                  weight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            sessionLabel.isNotEmpty ? sessionLabel : 'Admin',
            textAlign: TextAlign.center,
            style: orgText(p, size: 22, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Center(child: AdminBadge.info('Administrator')),
          const SizedBox(height: 24),
          Divider(height: 1, color: p.border),
          _profileDetail(Icons.mail_outline, 'EMAIL', currentEmail),
          _profileDetail(
            Icons.calendar_today_outlined,
            'MEMBER SINCE',
            AdminSession.instance.memberSince != null
                ? formatAdminDate(AdminSession.instance.memberSince!)
                : '\u2014',
          ),
          Divider(height: 1, color: p.border),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'ACCOUNT STATUS',
                style: orgText(
                  p,
                  size: 11,
                  weight: FontWeight.w700,
                  color: p.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSignedIn ? p.success : p.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isSignedIn ? 'Signed in' : 'Signed out',
                style: orgText(
                  p,
                  size: 13,
                  weight: FontWeight.w700,
                  color: isSignedIn ? p.success : p.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileDetail(IconData icon, String label, String value) {
    final p = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: orgText(
                    p,
                    size: 11,
                    weight: FontWeight.w700,
                    color: p.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: orgText(p, size: 14, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (label != 'MEMBER SINCE')
            Icon(Icons.lock_outline, size: 16, color: p.textSecondary),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    final p = FairTixPalette.of(context);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: Icons.lock_outline,
            title: 'Change Password',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, box) {
                  // Current password on its own row, then New + Confirm side by
                  // side; everything stacks on narrow cards.
                  final sideBySide = box.maxWidth >= 560;
                  final fieldWidth = sideBySide
                      ? (box.maxWidth - 16) / 2
                      : box.maxWidth;

                  final current = _passwordField(
                    'Current Password',
                    _currentPasswordController,
                    _showCurrentPassword,
                    () => setState(
                      () => _showCurrentPassword = !_showCurrentPassword,
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Enter your current password.'
                        : null,
                  );
                  final newField = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _passwordField(
                        'New Password',
                        _newPasswordController,
                        _showNewPassword,
                        () => setState(
                          () => _showNewPassword = !_showNewPassword,
                        ),
                        validator: (value) => (value ?? '').length < 8
                            ? 'Use at least 8 characters.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _strengthIndicator(),
                    ],
                  );
                  final confirm = _passwordField(
                    'Confirm New Password',
                    _confirmPasswordController,
                    _showConfirmPassword,
                    () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword,
                    ),
                    validator: (value) => value != _newPasswordController.text
                        ? 'Passwords do not match.'
                        : null,
                  );
                  final note = Text(
                    'Your name and email stay locked to your admin account. Only your password can be changed here.',
                    style: orgText(
                      p,
                      size: 12,
                      color: p.textSecondary,
                      height: 1.4,
                    ),
                  );
                  final save = AdminHeaderButton(
                    label: _isSavingPassword ? 'Saving...' : 'Save Changes',
                    filled: true,
                    onPressed: _isSavingPassword ? null : _savePassword,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: fieldWidth),
                          child: current,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (sideBySide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: newField),
                            const SizedBox(width: 16),
                            Expanded(child: confirm),
                          ],
                        )
                      else ...[
                        newField,
                        const SizedBox(height: 18),
                        confirm,
                      ],
                      const SizedBox(height: 22),
                      Divider(height: 1, color: p.border),
                      const SizedBox(height: 16),
                      if (sideBySide)
                        Row(
                          children: [
                            Expanded(child: note),
                            const SizedBox(width: 16),
                            save,
                          ],
                        )
                      else ...[
                        note,
                        const SizedBox(height: 14),
                        Align(alignment: Alignment.centerLeft, child: save),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller,
    bool visible,
    VoidCallback onToggle, {
    String? Function(String?)? validator,
  }) {
    final p = FairTixPalette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return Padding(
      padding: EdgeInsets.zero,
      child: TextFormField(
        controller: controller,
        obscureText: !visible,
        validator: validator,
        cursorColor: p.accentLabel,
        style: orgText(p, size: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: orgText(p, size: 14, weight: FontWeight.w700),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
          hintStyle: orgText(p, size: 14, color: p.textSecondary),
          errorStyle: orgText(p, size: 12, color: p.danger),
          filled: true,
          fillColor: p.surface,
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(
              visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 19,
              color: p.textSecondary,
            ),
            tooltip: visible ? 'Hide password' : 'Show password',
          ),
          contentPadding: const EdgeInsets.fromLTRB(14, 16, 6, 14),
          border: border(p.border),
          enabledBorder: border(p.border),
          focusedBorder: border(p.accentLabel),
          errorBorder: border(p.danger),
          focusedErrorBorder: border(p.danger),
        ),
      ),
    );
  }

  Widget _strengthIndicator() {
    final p = FairTixPalette.of(context);
    final password = _newPasswordController.text;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    final String label;
    final Color color;
    if (password.isEmpty) {
      label = 'Enter a new password';
      color = p.textSecondary;
    } else if (score <= 1) {
      label = 'Password strength: Weak';
      color = p.danger;
    } else if (score <= 3) {
      label = 'Password strength: Medium';
      color = p.warning;
    } else {
      label = 'Password strength: Strong';
      color = p.success;
    }

    Widget bar(int index) {
      final filled = password.isEmpty ? 0 : (score.clamp(0, 5) / 5 * 3).ceil();
      return Expanded(
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            color: index < filled ? color : p.progressTrack,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              bar(0),
              const SizedBox(width: 4),
              bar(1),
              const SizedBox(width: 4),
              bar(2),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: orgText(p, size: 12, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    final p = FairTixPalette.of(context);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: Icons.access_time,
            title: 'Recent Activity',
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Activity logging isn\u2019t built yet \u2014 actions you take (approvals, suspensions, etc.) aren\u2019t recorded to a log for display here.',
                textAlign: TextAlign.center,
                style: orgText(
                  p,
                  size: 13,
                  color: p.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _PanelHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: p.isDark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: p.accentLabel, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: orgText(p, size: 16, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
