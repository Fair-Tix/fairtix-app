import 'package:flutter/material.dart';

import '../../services/registration_draft.dart';
import '../../models/legal_terms.dart';
import '../../services/user_auth_service.dart';
import '../../theme/page_transitions.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_registration_ui.dart';
import 'otp_verification_screen.dart';
import 'terms_privacy_screen.dart';

/// Registration, Step 1 of 5: full name, email and password.
///
/// Step 2 is the email code, so the Supabase sign-up (which is what sends
/// that code) happens when this step is submitted. The account stays
/// unconfirmed, with no session, until the code is verified.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  // Letters (any language), spaces, and the punctuation found in real names.
  static final RegExp _namePattern = RegExp(
    r"^[\p{L}][\p{L}\p{M}\s.'’\-]*$",
    unicode: true,
  );
  static const int _minPasswordLength = 8;
  static const String _offlineMessage =
      'We couldn’t reach FairTix. Check your connection and try again.';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _acceptedTerms = false;
  bool _showFieldErrors = false;
  String? _error;

  // The email/password the sign-up already succeeded for. If the user goes
  // back from Step 2 and continues again without changing them, we don't sign
  // up a second time. Memory only; it dies with this screen.
  String? _createdEmail;
  String? _createdPassword;

  @override
  void initState() {
    super.initState();
    final draft = RegistrationDraft.instance;
    _nameController.text = draft.fullName;
    _emailController.text = draft.email;
  }

  @override
  void dispose() {
    // Leaving Step 1 for good (back to Login, or registration finished).
    RegistrationDraft.instance.clear();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  String? _validateName(String? value) {
    final name = _normalizeName(value ?? '');
    if (name.isEmpty) return 'Enter your full name.';
    if (!_namePattern.hasMatch(name)) {
      return 'Use letters only, exactly as shown on your ID.';
    }
    if (!name.contains(' ')) return 'Enter your first and last name.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password.';
    if (value.length < _minPasswordLength) {
      return 'Use at least $_minPasswordLength characters.';
    }
    return null;
  }

  /// Turns raw auth errors into something a person can act on.
  String _friendlyError(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('already exists') || m.contains('already registered')) {
      return 'An account with this email already exists. Try logging in instead.';
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

  Future<void> _handleCreateAccount() async {
    if (_isSubmitting) return; // no double submits
    FocusScope.of(context).unfocus();
    setState(() {
      _showFieldErrors = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      setState(() => _error = 'Accept the Terms & Privacy Policy to continue.');
      return;
    }

    final fullName = _normalizeName(_nameController.text);
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    // Keep for the next steps and for coming back to this one.
    RegistrationDraft.instance
      ..fullName = fullName
      ..email = email;

    final alreadyCreated = _createdEmail == email && _createdPassword == password;
    if (!alreadyCreated) {
      setState(() => _isSubmitting = true);
      try {
        await UserAuthService.instance.register(
          fullName: fullName,
          email: email,
          password: password,
          termsVersion: kTermsVersion,
        );
        _createdEmail = email;
        _createdPassword = password;
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
      setState(() => _isSubmitting = false);
    }

    // Step 2 of 5: enter the code that was emailed.
    Navigator.of(context).push(ftFadeRoute(OtpVerificationScreen(email: email)));
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _error = message;
    });
  }

  // Terms and Privacy are one screen with two tabs; each link opens its tab.
  void _openLegal({required bool privacy}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TermsPrivacyScreen(initialTab: privacy ? 1 : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FtRegistrationScaffold(
      followTheme: true,
      step: 1,
      title: 'Create your account',
      subtitle: 'Your name and email must match your ID.',
      onBack: _isSubmitting ? null : () => Navigator.of(context).maybePop(),
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
                  label: 'Full name',
                  controller: _nameController,
                  hintText: 'As shown on your ID',
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  enabled: !_isSubmitting,
                  validator: _validateName,
                ),
                const SizedBox(height: 24),
                FtTextField(
                  label: 'Email',
                  controller: _emailController,
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  enabled: !_isSubmitting,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 24),
                FtTextField(
                  label: 'Password',
                  controller: _passwordController,
                  hintText: 'At least 8 characters',
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !_isSubmitting,
                  validator: _validatePassword,
                  onSubmitted: (_) => _handleCreateAccount(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _acceptedTerms,
              onChanged: _isSubmitting ? null : (value) => setState(() {
                _acceptedTerms = value ?? false;
                _error = null;
              }),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(children: [
                  const Text('I have read and accept the '),
                  TextButton(onPressed: () => _openLegal(privacy: false), child: const Text('Terms')),
                  const Text(' and '),
                  TextButton(onPressed: () => _openLegal(privacy: true), child: const Text('Privacy Policy')),
                ]),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          FtBanner(message: _error!),
        ],
      ],
      button: FtGradientButton(
        label: 'Create Account',
        loading: _isSubmitting,
        onPressed: _isSubmitting ? null : _handleCreateAccount,
      ),
      footer: FtLegalText(
        onTerms: () => _openLegal(privacy: false),
        onPrivacy: () => _openLegal(privacy: true),
      ),
    );
  }
}
