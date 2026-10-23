import 'package:flutter/material.dart';

import '../../services/password_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import '../../widgets/theme_mode_switch.dart';
import 'organizer-scaffold.dart';

/// Change Password (Mahilum design): "Profile" crumb, big title, and one card
/// with the three password fields plus Cancel / Update Password.
///
/// This is the only self-service edit reachable from [OrganizerProfileScreen]:
/// full name and email stay locked to the organizer's verified ID and
/// proof-of-organization documents (capstone Account Verification rules).
class OrganizerChangePasswordScreen extends StatefulWidget {
  const OrganizerChangePasswordScreen({super.key});

  @override
  State<OrganizerChangePasswordScreen> createState() =>
      _OrganizerChangePasswordScreenState();
}

class _OrganizerChangePasswordScreenState
    extends State<OrganizerChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await PasswordService.instance.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      Navigator.pop(context);
    } on PasswordChangeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: FairTixPalette.of(context).danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _eye(FairTixPalette p, bool visible, VoidCallback onToggle) {
    return IconButton(
      tooltip: visible ? 'Hide password' : 'Show password',
      onPressed: onToggle,
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: p.accentLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerScaffold(
      pageTitle: 'Change Password',
      activeItem: OrganizerNavItem.profile,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: orgText(p, size: 15, color: p.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Change Password',
                      style: orgText(
                        p,
                        size: 36,
                        weight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const ThemeModeSwitch(),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: OrganizerCard(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OrganizerFieldLabel('Current password'),
                      const SizedBox(height: 7.5),
                      OrganizerTextField(
                        controller: _currentController,
                        hint: 'Current password',
                        obscureText: !_showCurrent,
                        suffix: _eye(
                          p,
                          _showCurrent,
                          () => setState(() => _showCurrent = !_showCurrent),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your current password.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      const OrganizerFieldLabel('New password'),
                      const SizedBox(height: 7.5),
                      OrganizerTextField(
                        controller: _newController,
                        hint: 'At least 8 characters',
                        obscureText: !_showNew,
                        suffix: _eye(
                          p,
                          _showNew,
                          () => setState(() => _showNew = !_showNew),
                        ),
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Use at least 8 characters.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      const OrganizerFieldLabel('Confirm new password'),
                      const SizedBox(height: 7.5),
                      OrganizerTextField(
                        controller: _confirmController,
                        hint: 'Re-enter new password',
                        obscureText: !_showNew,
                        onSubmitted: (_) => _isSaving ? null : _submit(),
                        validator: (v) => v != _newController.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: OrganizerSecondaryButton(
                              label: 'Cancel',
                              height: 44,
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 176,
                            child: OrganizerPrimaryButton(
                              label: 'Update Password',
                              height: 44,
                              loading: _isSaving,
                              onPressed: _submit,
                            ),
                          ),
                        ],
                      ),
                    ],
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
