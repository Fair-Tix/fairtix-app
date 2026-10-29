import 'package:flutter/material.dart';

import '../../services/organizer_auth_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';

/// "Forgot password?" pop-up for the organizer login.
///
/// Step 1: enter the account email and FairTix emails a 6-digit code.
/// Step 2: enter the code and a new password. Afterwards the organizer logs in
/// as usual with the new password.
///
/// [initialEmail] pre-fills the email the organizer already typed on the login
/// form.
Future<void> showOrganizerForgotPasswordDialog(
  BuildContext context, {
  String initialEmail = '',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email address of your account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OrganizerAuthService.instance.sendPasswordResetCode(email: email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _busy = false;
      });
    } on OrganizerAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _reset() async {
    if (_code.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters for the new password.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OrganizerAuthService.instance.resetPasswordWithCode(
        email: _email.text,
        token: _code.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Password updated. You can log in with it now.'),
        ),
      );
    } on OrganizerAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  InputDecoration _decoration(FairTixPalette p, String hint, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: orgText(p, size: 15, color: p.textSecondary),
      filled: true,
      fillColor: p.background,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(p.accentLabel, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reset your password',
                      style: orgText(p, size: 22, weight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _codeSent
                    ? 'We sent a 6-digit code to ${_email.text.trim()}. Enter it '
                          'below with your new password.'
                    : 'Enter your account email and we\u2019ll send you a '
                          '6-digit code.',
                style: orgText(p, size: 14, color: p.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              const OrganizerFieldLabel('Email'),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                enabled: !_codeSent && !_busy,
                keyboardType: TextInputType.emailAddress,
                style: orgText(p, size: 15),
                decoration: _decoration(p, 'you@organization.com'),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                const OrganizerFieldLabel('6-digit code'),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: orgText(p, size: 15, letterSpacing: 4),
                  decoration: _decoration(p, '123456').copyWith(counterText: ''),
                ),
                const SizedBox(height: 16),
                const OrganizerFieldLabel('New password'),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: !_showPassword,
                  style: orgText(p, size: 15),
                  decoration: _decoration(
                    p,
                    'At least 8 characters',
                    suffix: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: p.accentLabel,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const OrganizerFieldLabel('Confirm new password'),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: !_showPassword,
                  onSubmitted: (_) => _busy ? null : _reset(),
                  style: orgText(p, size: 15),
                  decoration: _decoration(p, 'Re-enter new password'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: orgText(p, size: 13, color: p.danger, height: 1.4),
                ),
              ],
              const SizedBox(height: 22),
              OrganizerPrimaryButton(
                label: _codeSent ? 'Update Password' : 'Send Code',
                height: 48,
                loading: _busy,
                onPressed: _codeSent ? _reset : _sendCode,
              ),
              if (_codeSent) ...[
                const SizedBox(height: 10),
                Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _busy ? null : _sendCode,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Send a new code',
                          style: orgText(
                            p,
                            size: 13,
                            weight: FontWeight.w700,
                            color: p.accentLabel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
