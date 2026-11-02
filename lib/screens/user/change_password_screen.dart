import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/password_service.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_otp_field.dart';
import '../../widgets/ft_subpage_ui.dart';

/// Lets the signed-in eventgoer change their password via Supabase Auth.
/// This is the only self-service edit on [ProfileScreen]: full name and
/// email stay locked to the verified ID document per the capstone's
/// Account Verification rules. Dark design; the password change itself still
/// goes through [PasswordService] (current password re-checked first).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? FtColors.dangerSurface : FtColors.otpFill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: (error ? FtColors.danger : FtColors.success).withValues(alpha: 0.5),
            ),
          ),
          content: Text(
            message,
            style: FtText.banner().copyWith(color: error ? FtColors.danger : Colors.white),
          ),
        ),
      );
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await PasswordService.instance.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      _toast('Password changed successfully.');
      Navigator.of(context).maybePop();
    } on PasswordChangeException catch (e) {
      if (!mounted) return;
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _requirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: FtColors.otpSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.3,
              color: FtColors.otpSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FtSubpageScaffold(
      title: 'Change Password',
      onBack: _isSaving ? null : () => Navigator.of(context).maybePop(),
      body: [
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AutofillGroup(
            child: Column(
              children: [
                FtTextField(
                  label: 'Current password',
                  controller: _currentController,
                  hintText: 'Your current password',
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_isSaving,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your current password.' : null,
                ),
                const SizedBox(height: 24),
                FtTextField(
                  label: 'New password',
                  controller: _newController,
                  hintText: 'At least 8 characters',
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !_isSaving,
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Use at least 8 characters.';
                    if (v == _currentController.text) {
                      return 'Choose a password different from your current one.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FtTextField(
                  label: 'Confirm new password',
                  controller: _confirmController,
                  hintText: 'Re-enter new password',
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !_isSaving,
                  validator: (v) => v != _newController.text ? 'Passwords do not match.' : null,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _requirement('At least 8 characters'),
              _requirement('Different from your current password'),
            ],
          ),
        ),
      ],
      bottomButton: FtVerifyButton(
        label: 'Update Password',
        loading: _isSaving,
        onPressed: _submit,
      ),
    );
  }
}
