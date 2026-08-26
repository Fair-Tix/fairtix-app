import 'package:flutter/material.dart';

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

  int _day = 12;
  String _month = 'March';
  int _year = 2003;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    // TODO: validate fields and create the Firebase Auth account here.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: _emailController.text)),
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
                children: [
                  Expanded(
                    child: LightPillField(controller: _firstNameController, hintText: 'First name'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LightPillField(controller: _lastNameController, hintText: 'Last name'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LightPillField(
                label: 'Email Address',
                controller: _emailController,
                hintText: 'herondave@gmail.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              LightPillField(
                label: 'Username',
                controller: _usernameController,
                hintText: '@herondave',
              ),
              const SizedBox(height: 18),
              Text('Phone Number', style: AppTextStyles.fieldLabelLight),
              const SizedBox(height: 8),
              Row(
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
              const SizedBox(height: 28),
              GradientPillButton(label: 'Continue', onPressed: _handleContinue),
            ],
          ),
        ),
      ),
    );
  }
}
