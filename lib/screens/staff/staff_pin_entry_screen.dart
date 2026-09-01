import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/scanner_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_pill_button.dart';
import 'staff_qr_scan_screen.dart';

/// Entry-staff access screen: paste the scanner link the organizer shared
/// (see OrganizerScannerSessionScreen), enter the 4-digit PIN, and get
/// into the QR scanning screen for that event.
///
/// Deliberately account-free — entry staff don't sign in to FairTix at
/// all; knowing the link + PIN pair (handed out by the organizer,
/// separately, per FairTix's design) is what authorizes scanning for one
/// event. See validate_scanner_session in supabase/scanner_functions.sql.
///
/// NOTE: real deep-linking (tapping the shared link opening this screen
/// directly, with the token pre-filled) isn't wired up in this pass —
/// that needs platform-level App Links/Universal Links configuration,
/// tracked separately. For now staff reach this screen via the "Entry
/// Staff?" link on the sign-in screen and paste the link manually.
class StaffPinEntryScreen extends StatefulWidget {
  const StaffPinEntryScreen({super.key});

  @override
  State<StaffPinEntryScreen> createState() => _StaffPinEntryScreenState();
}

class _StaffPinEntryScreenState extends State<StaffPinEntryScreen> {
  final _linkController = TextEditingController();
  final List<TextEditingController> _pinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _linkController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _pin => _pinControllers.map((c) => c.text).join();

  Future<void> _handleSubmit() async {
    final link = _linkController.text.trim();
    final pin = _pin;

    if (link.isEmpty) {
      setState(() => _errorMessage = 'Enter the scanner link the organizer shared with you.');
      return;
    }
    if (pin.length != 4) {
      setState(() => _errorMessage = 'Enter the full 4-digit PIN.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final access = await ScannerRepository.instance.validateAccess(linkOrToken: link, pin: pin);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => StaffQrScanScreen(access: access)),
      );
    } on ScannerRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onPinDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _pinFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _pinFocusNodes[index - 1].requestFocus();
    }
    if (_pin.length == 4) _handleSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.accentPurple, size: 30),
                ),
                const SizedBox(height: 20),
                const Text('Entry Staff Access', style: AppTextStyles.sectionHeading),
                const SizedBox(height: 6),
                const Text(
                  'Paste the scanner link and enter the 4-digit PIN your organizer shared with you.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 28),
                const Text('SCANNER LINK', style: AppTextStyles.cardLabel),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  style: AppTextStyles.fieldInputLight,
                  decoration: InputDecoration(
                    hintText: 'https://fairtix.app/scan/...',
                    filled: true,
                    fillColor: AppColors.inputFillLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('4-DIGIT PIN', style: AppTextStyles.cardLabel),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    return SizedBox(
                      width: 64,
                      height: 64,
                      child: TextField(
                        controller: _pinControllers[index],
                        focusNode: _pinFocusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        obscureText: true,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.inputFillLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) => _onPinDigitChanged(index, value),
                      ),
                    );
                  }),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 12.5, color: AppColors.error, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                GradientPillButton(
                  label: 'Continue',
                  loading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
