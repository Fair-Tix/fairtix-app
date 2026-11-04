import 'package:flutter/material.dart';

import '../../services/admin_auth_service.dart';
import '../organizer/app_colors.dart';
import '../../theme/fairtix_palette.dart';
import 'admin-dashboard.dart';
import 'admin-route.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, this.initialErrorText});

  final String? initialErrorText;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _errorText = widget.initialErrorText;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await AdminAuthService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      adminPushReplacement(context, const AdminDashboardScreen());
    } on AdminAuthException catch (error) {
      if (mounted) setState(() => _errorText = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: palette.background,
      body: Row(
        children: [
          if (isWide) const Expanded(flex: 39, child: _AdminBrandPanel()),
          Expanded(
            flex: 61,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 64,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 410),
                  child: _buildLoginCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    final palette = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(34, 30, 34, 32),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
        boxShadow: palette.isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AdminLogo(),
            Padding(
              padding: EdgeInsets.only(top: 18),
              child: Divider(color: palette.border),
            ),
            const SizedBox(height: 26),
            Text(
              'Admin Portal',
              textAlign: TextAlign.center,
              style: AppTextStyles.h1.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Restricted access - authorized personnel only',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            if (AdminAuthService.debugCredentialsHint.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.progressTrack,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Test account: ${AdminAuthService.debugCredentialsHint}',
                  style: AppTextStyles.bodyGray.copyWith(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            _field(
              label: 'Email Address',
              hint: 'Email Adress',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 18),
            _field(
              label: 'Password',
              hint: 'Enter your password',
              controller: _passwordController,
              obscureText: _obscurePassword,
              prefixIcon: Icon(
                Icons.lock_outline,
                size: 20,
                color: palette.textSecondary,
              ),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: palette.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Password is required'
                  : null,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: TextStyle(color: palette.danger, fontSize: 13),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password reset is coming soon. Please contact support.',
                    ),
                  ),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _isSubmitting
                ? const SizedBox(
                    height: 52,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : PrimaryButton(
                    label: 'Log In',
                    onPressed: _handleLogin,
                    isGradient: true,
                    height: 52,
                  ),
            Padding(
              padding: EdgeInsets.only(top: 18, bottom: 16),
              child: Divider(color: palette.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: palette.textSecondary,
                ),
                SizedBox(width: 7),
                Text(
                  'This portal is not publicly accessible.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final palette = FairTixPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: palette.textPrimary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: AppTextStyles.body.copyWith(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyGray.copyWith(
              color: palette.textSecondary,
              fontSize: 12,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            filled: true,
            fillColor: palette.surface,
            border: _border(palette.border),
            enabledBorder: _border(palette.border),
            focusedBorder: _border(palette.primary),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: BorderSide(color: color),
  );
}

class _AdminBrandPanel extends StatelessWidget {
  const _AdminBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7135E8), Color(0xFFB24DF2)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: 90, left: 54, child: _Circle(120)),
          const Positioned(top: 150, right: -30, child: _Circle(90)),
          const Positioned(bottom: 135, left: 100, child: _Circle(155)),
          const Positioned(bottom: 105, right: 115, child: _Circle(100)),
          Padding(
            padding: const EdgeInsets.fromLTRB(68, 104, 40, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AdminLogo(light: true),
                const SizedBox(height: 26),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const Spacer(),
                const Text(
                  'Admin Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fair tickets.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  const _Circle(this.size);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}

class _AdminLogo extends StatelessWidget {
  final bool light;
  const _AdminLogo({this.light = false});

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    final color = light ? Colors.white : palette.textPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple,
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(
            Icons.confirmation_number_outlined,
            color: Colors.white,
            size: 15,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'FairTix',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 3),
        const Text(
          'Admin',
          style: TextStyle(color: AppColors.primaryPurpleLight, fontSize: 13),
        ),
      ],
    );
  }
}
