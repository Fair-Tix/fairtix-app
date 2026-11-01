import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AutofillHints;

import '../../models/app_user.dart';
import '../../navigation/main_shell.dart';
import '../../services/user_auth_service.dart';
import '../../theme/page_transitions.dart';
import '../../widgets/ft_dark_ui.dart';
import '../staff/staff_pin_entry_screen.dart';
import 'forgot_password_screen.dart';
import 'registration_screen.dart';

/// Picks the first screen for a signed-in eventgoer. Shared by the login flow
/// and app startup (session restore) so both land in the same place.
///
/// Every signed-in eventgoer lands on Home, whatever their approval status.
/// Until an admin approves the account they can browse and view events, but
/// buying tickets and reselling stay locked: the app explains why (and offers
/// to submit or resubmit the ID) when they try, via `ensureBuyerApproved` in
/// services/access_control.dart, and the database enforces the same rule.
Widget userHomeFor(AppUser account) => const MainShell();

/// First screen for anyone who is not signed in (shown right after the
/// loading screen). Dark FairTix design.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const String _offlineMessage =
      'We couldn’t reach FairTix. Check your connection and try again.';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showFieldErrors = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return null;
  }

  /// Turns raw auth errors into something a person can act on.
  String _friendlyError(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login credentials') ||
        m.contains('invalid email or password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email first. Check your inbox for the code.';
    }
    if (m.contains('too many') || m.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (m.contains('socket') ||
        m.contains('failed host lookup') ||
        m.contains('clientexception') ||
        m.contains('network') ||
        m.contains('timed out')) {
      return _offlineMessage;
    }
    return raw;
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return; // no double submits
    FocusScope.of(context).unfocus();
    setState(() {
      _showFieldErrors = true;
      _error = null;
      _notice = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    AppUser account;
    try {
      account = await UserAuthService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on UserAuthException catch (e) {
      _fail(_friendlyError(e.message));
      return;
    } catch (_) {
      // Network failures and anything unexpected: never leave the button
      // spinning forever.
      _fail(_offlineMessage);
      return;
    }
    if (!mounted) return;

    // Stay in the loading state while navigating, so a second tap can't start
    // another login.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => userHomeFor(account)),
      (route) => false,
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = message;
    });
  }

  Future<void> _openForgotPassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );
    if (changed == true && mounted) {
      setState(() {
        _error = null;
        _notice = 'Password updated. Log in with your new password.';
        _passwordController.clear();
      });
    }
  }

  void _openRegistration() {
    Navigator.of(context).push(
      ftFadeRoute(const RegistrationScreen()),
    );
  }

  void _openStaffEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StaffPinEntryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FtAuthScaffold(
      title: 'Log in',
      subtitle: 'Enter your details to continue.',
      body: [
        Form(
          key: _formKey,
          autovalidateMode: _showFieldErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: AutofillGroup(
            child: Column(
              children: [
                FtTextField(
                  label: 'Email',
                  controller: _emailController,
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  enabled: !_isLoading,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 26),
                FtTextField(
                  label: 'Password',
                  controller: _passwordController,
                  hintText: 'Enter your password',
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_isLoading,
                  validator: _validatePassword,
                  onSubmitted: (_) => _handleLogin(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: _isLoading ? null : _openForgotPassword,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Text('Forgot password?', style: FtText.link()),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          FtBanner(message: _error!),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 12),
          FtBanner(message: _notice!, isError: false),
        ],
      ],
      button: FtGradientButton(
        label: 'Log In',
        loading: _isLoading,
        onPressed: _isLoading ? null : _handleLogin,
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('New to FairTix? ', style: FtText.footer()),
              InkWell(
                onTap: _isLoading ? null : _openRegistration,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Text('Create account', style: FtText.link()),
                ),
              ),
            ],
          ),
          // Entry staff have no account, so this is their only way in.
          InkWell(
            onTap: _isLoading ? null : _openStaffEntry,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(
                'Entry staff? Scan tickets',
                style: FtText.footer().copyWith(
                  fontSize: 12.5,
                  color: FtColors.hint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
