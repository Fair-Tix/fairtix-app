import 'package:flutter/material.dart';

import '../../services/user_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/light_pill_field.dart';
import '../../widgets/purple_header_bar.dart';
import 'otp_verification_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _day = 12;
  String _month = 'March';
  int _year = 2003;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  // Field-level validation messages, keyed by field name. Populated by
  // [_validate] right before a submit attempt.
  final Map<String, String?> _errors = {};

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  static final _phoneDigitsPattern = RegExp(r'^\d{10}$');

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  DateTime get _birthDate => DateTime(_year, _months.indexOf(_month) + 1, _day);

  /// Runs all field validations, stores messages in [_errors], and returns
  /// whether the form is valid overall.
  bool _validate() {
    final errors = <String, String?>{};

    if (_firstNameController.text.trim().isEmpty) {
      errors['firstName'] = 'Required';
    }
    if (_lastNameController.text.trim().isEmpty) {
      errors['lastName'] = 'Required';
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      errors['email'] = 'Email is required';
    } else if (!_emailPattern.hasMatch(email)) {
      errors['email'] = 'Enter a valid email address';
    }

    final username = _usernameController.text.trim().replaceFirst('@', '');
    if (username.isEmpty) {
      errors['username'] = 'Username is required';
    } else if (!_usernamePattern.hasMatch(username)) {
      errors['username'] = '3-20 letters, numbers, or underscores';
    }

    final phoneDigits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.isEmpty) {
      errors['phone'] = 'Phone number is required';
    } else if (!_phoneDigitsPattern.hasMatch(phoneDigits)) {
      errors['phone'] = 'Enter a valid 10-digit mobile number';
    }

    final now = DateTime.now();
    final hasHadBirthdayThisYear = now.month > _birthDate.month ||
        (now.month == _birthDate.month && now.day >= _birthDate.day);
    final age = now.year - _birthDate.year - (hasHadBirthdayThisYear ? 0 : 1);
    if (age < 13) {
      errors['birthday'] = 'You must be at least 13 years old';
    }

    final password = _passwordController.text;
    if (password.length < 8) {
      errors['password'] = 'At least 8 characters';
    }

    if (_confirmPasswordController.text != password) {
      errors['confirmPassword'] = 'Passwords do not match';
    }

    setState(() => _errors
      ..clear()
      ..addAll(errors));

    return errors.isEmpty;
  }

  Future<void> _handleContinue() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);

    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
    final username = _usernameController.text.trim().replaceFirst('@', '');
    final email = _emailController.text.trim();
    final phone = '+63${_phoneController.text.trim().replaceAll(RegExp(r'\D'), '')}';

    try {
      await UserAuthService.instance.register(
        fullName: fullName,
        username: username,
        email: email,
        phone: phone,
        password: _passwordController.text,
        birthDate: _birthDate,
      );
    } on UserAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Create Account',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Personal Info', style: AppTextStyles.sectionHeading),
              const SizedBox(height: 20),
              Text('Your Name', style: AppTextStyles.fieldLabelLight),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LightPillField(
                      controller: _firstNameController,
                      hintText: 'First name',
                      errorText: _errors['firstName'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LightPillField(
                      controller: _lastNameController,
                      hintText: 'Last name',
                      errorText: _errors['lastName'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LightPillField(
                label: 'Email Address',
                controller: _emailController,
                hintText: 'herondave@gmail.com',
                keyboardType: TextInputType.emailAddress,
                errorText: _errors['email'],
              ),
              const SizedBox(height: 18),
              LightPillField(
                label: 'Username',
                controller: _usernameController,
                hintText: '@herondave',
                errorText: _errors['username'],
              ),
              const SizedBox(height: 18),
              Text('Phone Number', style: AppTextStyles.fieldLabelLight),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.inputFillLight,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.inputBorderLight),
                    ),
                    child: const Text('🇵🇭 +63', style: AppTextStyles.fieldInputLight),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LightPillField(
                      controller: _phoneController,
                      hintText: '912 345 6789',
                      keyboardType: TextInputType.phone,
                      errorText: _errors['phone'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Birthday', style: AppTextStyles.fieldLabelLight),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LightPillDropdown<int>(
                      value: _day,
                      items: List.generate(31, (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (v) => setState(() => _day = v ?? _day),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: LightPillDropdown<String>(
                      value: _month,
                      items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setState(() => _month = v ?? _month),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LightPillDropdown<int>(
                      value: _year,
                      items: List.generate(90, (i) => 2025 - i)
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) => setState(() => _year = v ?? _year),
                    ),
                  ),
                ],
              ),
              if (_errors['birthday'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errors['birthday']!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 18),
              LightPillField(
                label: 'Password',
                controller: _passwordController,
                hintText: 'At least 8 characters',
                obscureText: _obscurePassword,
                errorText: _errors['password'],
                suffixWidget: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 18),
              LightPillField(
                label: 'Confirm Password',
                controller: _confirmPasswordController,
                hintText: 'Re-enter your password',
                obscureText: _obscureConfirmPassword,
                errorText: _errors['confirmPassword'],
                suffixWidget: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              const SizedBox(height: 28),
              GradientPillButton(
                label: 'Continue',
                loading: _isSubmitting,
                onPressed: _handleContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
