import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/scanner_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import '../../widgets/top_glow_background.dart';
import 'staff_qr_scan_screen.dart';

/// Entry-staff access screen (Mahilum "4-Digit PIN" design): enter the PIN the
/// organizer shared (see OrganizerScannerSessionScreen) on a custom keypad and
/// get into the QR scanning screen for that event.
///
/// Deliberately account-free: entry staff don't sign in to FairTix at all;
/// knowing the PIN (handed out by the organizer) is what authorizes scanning
/// for one event. See validate_scanner_session in
/// supabase/scanner_functions.sql. Staff reach this screen via the "Entry
/// Staff?" link on the sign-in screen.
///
/// The design shows the event name as the title. The event is only known once
/// the PIN has been validated, so this screen uses a generic title instead.
class StaffPinEntryScreen extends StatefulWidget {
  const StaffPinEntryScreen({super.key});

  @override
  State<StaffPinEntryScreen> createState() => _StaffPinEntryScreenState();
}

class _StaffPinEntryScreenState extends State<StaffPinEntryScreen> {
  static const int _pinLength = 4;

  String _pin = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  void _addDigit(String digit) {
    if (_isSubmitting || _pin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == _pinLength) _handleSubmit();
  }

  void _backspace() {
    if (_isSubmitting || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (_pin.length != _pinLength) {
      setState(() => _errorMessage = 'Enter the full 4-digit PIN.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final access = await ScannerRepository.instance.validateAccess(pin: _pin);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => StaffQrScanScreen(access: access)),
      );
    } on ScannerRepositoryException catch (e) {
      if (!mounted) return;
      // Wrong PIN (or a revoked/expired session): clear the dots so staff can
      // retype straight away.
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _errorMessage = e.message;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final c = event.character;
    if (c != null && c.length == 1 && c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
      _addDigit(c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            const TopGlowBackground(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'SCANNER SESSION',
                          style: orgText(
                            p,
                            size: 12,
                            weight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: p.accentLabel,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Entry Staff Access',
                          style: orgText(
                            p,
                            size: 26,
                            weight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter the 4-digit PIN from your organizer.',
                          style: orgText(
                            p,
                            size: 15,
                            color: p.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _PinDots(filled: _pin.length, total: _pinLength),
                        SizedBox(
                          height: 38,
                          child: Center(
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: p.accentLabel,
                                    ),
                                  )
                                : Text(
                                    _errorMessage ?? '',
                                    textAlign: TextAlign.center,
                                    style: orgText(
                                      p,
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: p.danger,
                                      height: 1.3,
                                    ),
                                  ),
                          ),
                        ),
                        _Keypad(
                          enabled: !_isSubmitting,
                          onDigit: _addDigit,
                          onBackspace: _backspace,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'This session ends when the event ends.',
                          textAlign: TextAlign.center,
                          style: orgText(
                            p,
                            size: 14,
                            color: p.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? p.accentLabel : Colors.transparent,
              border: Border.all(
                color: i < filled ? p.accentLabel : p.border,
                width: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _Key(
          label: d,
          onTap: enabled ? () => onDigit(d) : null,
        );

    Widget row(List<Widget> keys) => Padding(
          padding: const EdgeInsets.only(bottom: _gap),
          child: Row(
            children: [
              for (var i = 0; i < keys.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: keys[i]),
              ],
            ],
          ),
        );

    return Column(
      children: [
        row([digit('1'), digit('2'), digit('3')]),
        row([digit('4'), digit('5'), digit('6')]),
        row([digit('7'), digit('8'), digit('9')]),
        Row(
          children: [
            const Expanded(child: _Key()), // blank, as in the design
            const SizedBox(width: _gap),
            Expanded(child: digit('0')),
            const SizedBox(width: _gap),
            Expanded(
              child: _Key(
                icon: Icons.backspace_outlined,
                semanticLabel: 'Delete',
                onTap: enabled ? onBackspace : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.onTap, this.semanticLabel});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(22);
    final blank = label == null && icon == null;

    return Semantics(
      button: !blank,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        borderRadius: radius,
        child: Ink(
          height: 63,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.border),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: blank ? null : onTap,
            child: Center(
              child: label != null
                  ? Text(
                      label!,
                      style: orgText(
                        p,
                        size: 26,
                        weight: FontWeight.w700,
                        height: 1.1,
                      ),
                    )
                  : icon != null
                      ? Icon(icon, size: 24, color: p.textPrimary)
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}
