import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../navigation/main_shell.dart';
import '../../services/user_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_text_field.dart';
import 'identity_verification_screen.dart';
import 'registration_pending_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    AppUser account;
    try {
      account = await UserAuthService.instance.login(
        email: _usernameController.text,
        password: _passwordController.text,
      );
    } on UserAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Route based on the account's real id_verification_status rather
    // than always going Home:
    //  - verified            -> straight into the app
    //  - pending, no ID yet  -> still mid-registration; resume ID upload
    //  - pending, ID on file -> "Verification Pending" (under admin review)
    //  - rejected            -> treat like "no ID yet" so they can resubmit
    if (account.idVerificationStatus == 'verified') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } else if (account.idDocumentUrl == null || account.idVerificationStatus == 'rejected') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RegistrationPendingScreen(idType: account.idType),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Text('FairTix', style: AppTextStyles.logo),
              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Welcome back!', style: AppTextStyles.heading),
              ),
              if (UserAuthService.debugCredentialsHint.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.fieldBorder),
                  ),
                  child: Text(
                    'Test account: ${UserAuthService.debugCredentialsHint}',
                    style: AppTextStyles.footerText.copyWith(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PillTextField(
                label: 'Username',
                controller: _usernameController,
                hintText: 'you@email.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              PillTextField(
                label: 'Password',
                controller: _passwordController,
                hintText: '••••••••',
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: navigate to Forgot Password flow.
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Forgot Password?', style: AppTextStyles.link),
                ),
              ),
              const SizedBox(height: 28),
              PillButton(
                label: 'Log In',
                loading: _isLoading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: 48),
              Text('Or log in with', style: AppTextStyles.footerText),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialCircle(icon: Icons.g_mobiledata, onTap: () {}),
                  const SizedBox(width: 16),
                  _SocialCircle(icon: Icons.facebook, onTap: () {}),
                  const SizedBox(width: 16),
                  _SocialCircle(icon: Icons.apple, onTap: () {}),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                  );
                },
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.footerText,
                    children: const [
                      TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Sign Up',
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialCircle extends StatelessWidget {
  const _SocialCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.fieldBorder, width: 1),
        ),
        child: Icon(icon, color: AppColors.white, size: 26),
      ),
    );
  }
}
