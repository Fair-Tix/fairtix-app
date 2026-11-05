import 'package:flutter/material.dart';

import '../../services/admin_auth_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/fairtix_mark.dart';
import '../../widgets/organizer_ui.dart';
import '../../widgets/theme_mode_switch.dart';
import '../../widgets/top_glow_background.dart';
import 'admin-dashboard.dart';
import 'admin-route.dart';

/// Admin Log In. Mirrors the organizer login: brand panel on the left, form
/// on the right (form column 420 wide, inputs 54 tall, button 49 tall).
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
    final p = FairTixPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          Row(
            children: [
              if (isWide) Expanded(child: _BrandPanel(p: p)),
              Expanded(child: _buildFormPanel(p, showLogo: !isWide)),
            ],
          ),
          // Light / Dark switch, top-right.
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ThemeModeSwitch(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel(FairTixPalette p, {required bool showLogo}) {
    return Stack(
      children: [
        const TopGlowBackground(centerX: 0.03, radiusX: 660),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showLogo) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: FairTixMark(width: 104),
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _AdminChip(),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      'Admin Portal',
                      style: orgText(
                        p,
                        size: 28,
                        weight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Restricted access - authorized personnel only',
                      style: orgText(
                        p,
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: p.warning,
                        height: 1.4,
                      ),
                    ),
                    if (AdminAuthService.debugCredentialsHint.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Test account: ${AdminAuthService.debugCredentialsHint}',
                        style: orgText(p, size: 12, color: p.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _FieldLabel('Email', p: p),
                    const SizedBox(height: 7.5),
                    _AuthField(
                      p: p,
                      controller: _emailController,
                      hint: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Password', p: p),
                    const SizedBox(height: 7.5),
                    _AuthField(
                      p: p,
                      controller: _passwordController,
                      hint: 'Enter your password',
                      obscureText: _obscurePassword,
                      onSubmitted: (_) => _handleLogin(),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: p.textSecondary,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Password is required'
                          : null,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: orgText(
                          p,
                          size: 13,
                          weight: FontWeight.w600,
                          color: p.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16.5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _TextLink(
                        label: 'Forgot password?',
                        color: p.accentLabel,
                        onTap: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password reset is coming soon. Please contact support.',
                                ),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 19),
                    _SubmitButton(
                      label: 'Log In',
                      loading: _isSubmitting,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: p.textSecondary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'This portal is not publicly accessible.',
                          style: orgText(p, size: 12, color: p.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------------
// Left: brand panel
// -------------------------------------------------------------------------
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.p});

  final FairTixPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.border)),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 96, right: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FairTixMark(width: 190),
          const SizedBox(height: 14),
          const _AdminChip(),
          const SizedBox(height: 28),
          Text(
            'Admin Portal',
            style: orgText(
              p,
              size: 40,
              height: 1.1,
              weight: FontWeight.w800,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 18.6),
          Text(
            'Fair tickets.',
            style: orgText(p, size: 16, height: 1.56, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The small "ADMIN" tag shown under the logo.
class _AdminChip extends StatelessWidget {
  const _AdminChip();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: p.isDark ? 0.24 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ADMIN',
        style: orgText(
          p,
          size: 11,
          weight: FontWeight.w800,
          color: p.accentLabel,
          letterSpacing: 0.8,
          height: 1.2,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Small building blocks (same look as the organizer login)
// -------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.p});

  final String text;
  final FairTixPalette p;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: orgText(p, size: 13, height: 1.3, weight: FontWeight.w600),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.p,
    required this.controller,
    required this.hint,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
    this.suffixIcon,
  });

  final FairTixPalette p;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?) validator;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final textStyle = orgText(p, size: 14, height: 1.3);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: textStyle,
      cursorColor: p.accentLabel,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: textStyle.copyWith(color: p.textSecondary),
        errorStyle: orgText(p, size: 12, color: p.danger),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: p.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: suffixIcon == null ? 18 : 14,
        ),
        border: _border(p.border),
        enabledBorder: _border(p.border),
        focusedBorder: _border(p.accentLabel),
        errorBorder: _border(p.danger),
        focusedErrorBorder: _border(p.danger),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: orgText(
            p,
            size: 13,
            height: 1.3,
            weight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: p.primary.withValues(alpha: p.isDark ? 0.40 : 0.32),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          height: 49,
          decoration: BoxDecoration(
            gradient: FairTixPalette.buttonGradient,
            borderRadius: radius,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: orgText(
                        p,
                        size: 14,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
