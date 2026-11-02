import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/password_service.dart';
import '../../widgets/ft_dark_ui.dart';

/// Password recovery for signed-out eventgoers, in three steps:
/// email -> code from the email -> new password.
///
/// Pops with `true` once the password has been changed, so the login screen
/// can tell the user to log in with it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, code, password }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const String _offlineMessage =
      'We couldn’t reach FairTix. Check your connection and try again.';

  final _emailForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();

  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  bool _verified = false; // a recovery session is open
  bool _finished = false;
  bool _autoValidate = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    // Walked away after verifying the code: close the recovery session.
    if (_verified && !_finished) {
      unawaited(PasswordService.instance.abandonReset());
    }
    super.dispose();
  }

  /// Runs [task] with the loading guard (no double submits) and turns
  /// failures into an inline message. Returns true when it succeeded.
  Future<bool> _guard(Future<void> Function() task) async {
    if (_loading) return false;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    var ok = false;
    try {
      await task();
      ok = true;
    } on PasswordChangeException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = _offlineMessage;
    }
    if (mounted) setState(() => _loading = false);
    return ok && mounted;
  }

  bool _valid(GlobalKey<FormState> key) {
    setState(() => _autoValidate = true);
    return key.currentState?.validate() ?? false;
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_valid(_emailForm)) return;
    if (await _guard(() => PasswordService.instance.sendResetCode(_email.text))) {
      setState(() {
        _step = _Step.code;
        _autoValidate = false;
        _code.clear();
        if (resend) _notice = 'We sent you a new code.';
      });
    }
  }

  Future<void> _verifyCode() async {
    if (!_valid(_codeForm)) return;
    final ok = await _guard(
      () => PasswordService.instance.verifyResetCode(
        email: _email.text,
        code: _code.text,
      ),
    );
    if (ok) {
      setState(() {
        _verified = true;
        _step = _Step.password;
        _autoValidate = false;
      });
    }
  }

  Future<void> _savePassword() async {
    if (!_valid(_passwordForm)) return;
    final ok = await _guard(
      () => PasswordService.instance.setNewPasswordAfterReset(
        _newPassword.text,
      ),
    );
    if (ok && mounted) {
      _finished = true;
      Navigator.of(context).pop(true);
    }
  }

  void _changeEmail() {
    setState(() {
      _step = _Step.email;
      _error = null;
      _notice = null;
      _autoValidate = false;
    });
  }

  AutovalidateMode get _mode =>
      _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled;

  Widget _messages() => Column(
    children: [
      if (_error != null) ...[
        const SizedBox(height: 20),
        FtBanner(message: _error!),
      ],
      if (_notice != null) ...[
        const SizedBox(height: 20),
        FtBanner(message: _notice!, isError: false),
      ],
    ],
  );

  Widget _link(String label, VoidCallback? onTap) => InkWell(
    onTap: _loading ? null : onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(label, style: FtText.link()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.email:
        return FtAuthScaffold(
          title: 'Forgot password?',
          subtitle:
              'Enter the email you signed up with and we’ll send you a code.',
          body: [
            Form(
              key: _emailForm,
              autovalidateMode: _mode,
              child: FtTextField(
                label: 'Email',
                controller: _email,
                hintText: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                enabled: !_loading,
                onSubmitted: (_) => _sendCode(),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Enter your email.';
                  if (!_emailPattern.hasMatch(value)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
            ),
            _messages(),
          ],
          button: FtGradientButton(
            label: 'Send code',
            loading: _loading,
            onPressed: _loading ? null : _sendCode,
          ),
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Remembered it? ', style: FtText.footer()),
              _link('Log in', () => Navigator.of(context).maybePop()),
            ],
          ),
        );

      case _Step.code:
        return FtAuthScaffold(
          title: 'Check your email',
          subtitle:
              'If an account exists for ${_email.text.trim()}, we sent a code to it. Enter it below.',
          body: [
            Form(
              key: _codeForm,
              autovalidateMode: _mode,
              child: FtTextField(
                label: 'Code',
                controller: _code,
                hintText: 'Enter the code',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                enabled: !_loading,
                onSubmitted: (_) => _verifyCode(),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Enter the code from your email.';
                  if (value.length < 6) return 'The code has at least 6 digits.';
                  return null;
                },
              ),
            ),
            _messages(),
          ],
          button: FtGradientButton(
            label: 'Verify code',
            loading: _loading,
            onPressed: _loading ? null : _verifyCode,
          ),
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text('Didn’t get it?', style: FtText.footer()),
              _link('Resend code', () => _sendCode(resend: true)),
              Text('·', style: FtText.footer()),
              _link('Change email', _changeEmail),
            ],
          ),
        );

      case _Step.password:
        return FtAuthScaffold(
          title: 'New password',
          subtitle: 'Choose a new password for your FairTix account.',
          body: [
            Form(
              key: _passwordForm,
              autovalidateMode: _mode,
              child: AutofillGroup(
                child: Column(
                  children: [
                    FtTextField(
                      label: 'New password',
                      controller: _newPassword,
                      hintText: 'At least 8 characters',
                      isPassword: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      enabled: !_loading,
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    const SizedBox(height: 26),
                    FtTextField(
                      label: 'Confirm password',
                      controller: _confirmPassword,
                      hintText: 'Re-enter your new password',
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      enabled: !_loading,
                      onSubmitted: (_) => _savePassword(),
                      validator: (v) => v != _newPassword.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            _messages(),
          ],
          button: FtGradientButton(
            label: 'Save new password',
            loading: _loading,
            onPressed: _loading ? null : _savePassword,
          ),
        );
    }
  }
}
