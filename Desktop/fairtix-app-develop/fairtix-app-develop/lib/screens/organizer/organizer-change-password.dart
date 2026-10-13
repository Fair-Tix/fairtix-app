import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../services/password_service.dart';
import 'organizer-scaffold.dart';

/// Lets the signed-in organizer change their password via Supabase Auth.
/// This is the only self-service edit reachable from
/// [OrganizerProfileScreen] — full name and email stay locked to the
/// organizer's verified ID/proof-of-organization documents per the
/// capstone's Account Verification rules.
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
  bool _showConfirm = false;
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
        SnackBar(content: Text(e.message), backgroundColor: AppColors.dangerRed),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrganizerScaffold(
      pageTitle: 'Change Password',
      activeItem: OrganizerNavItem.profile,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Change Password', style: AppTextStyles.h2),
                  const SizedBox(height: 6),
                  const Text(
                    'Your name and email stay locked to your verified identity documents. Only your password can be changed here.',
                    style: AppTextStyles.bodyGray,
                  ),
                  const SizedBox(height: 24),
                  _field(
                    'Current Password',
                    _currentController,
                    _showCurrent,
                    () => setState(() => _showCurrent = !_showCurrent),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Enter your current password.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'New Password',
                    _newController,
                    _showNew,
                    () => setState(() => _showNew = !_showNew),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Use at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'Confirm New Password',
                    _confirmController,
                    _showConfirm,
                    () => setState(() => _showConfirm = !_showConfirm),
                    validator: (v) => v != _newController.text
                        ? 'Passwords do not match.'
                        : null,
                  ),
                  const SizedBox(height: 26),
                  PrimaryButton(
                    label: _isSaving ? 'Saving...' : 'Save New Password',
                    onPressed: _isSaving ? null : _submit,
                  ),
                  const SizedBox(height: 12),
                  OutlineButtonWidget(
                    label: 'Cancel',
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    bool visible,
    VoidCallback onToggle, {
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textGray,
                size: 20,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryPurple),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.dangerRed),
            ),
          ),
        ),
      ],
    );
  }
}
