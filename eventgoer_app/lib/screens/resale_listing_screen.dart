import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sample_tickets.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/purple_header_bar.dart';
import 'resale_confirmation_screen.dart';

/// "List for Resale" screen — lets the ticket owner set a resale price,
/// enforcing FairTix's system-wide resale band: the price must fall
/// between 50% (floor, to prevent nominal-price transfers that bypass
/// purchase limits) and 100% (ceiling, to prevent scalping) of the
/// ticket's original purchase price.
class ResaleListingScreen extends StatefulWidget {
  const ResaleListingScreen({super.key, required this.ticket});

  final Ticket ticket;

  @override
  State<ResaleListingScreen> createState() => _ResaleListingScreenState();
}

class _ResaleListingScreenState extends State<ResaleListingScreen> {
  late final TextEditingController _priceController;
  bool _isSubmitting = false;

  double get _minPrice => widget.ticket.minResalePrice;
  double get _maxPrice => widget.ticket.tier.price;

  bool get _windowClosed => widget.ticket.event.isResaleWindowClosed;

  double? get _enteredPrice {
    final raw = _priceController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? get _errorMessage {
    final text = _priceController.text.trim();
    if (text.isEmpty) return null;
    final value = _enteredPrice;
    if (value == null) return 'Enter a valid amount.';
    if (value < _minPrice || value > _maxPrice) {
      return 'Price must be between ${formatPeso(_minPrice)} and ${formatPeso(_maxPrice)} '
          '(50%\u2013100% of original price)';
    }
    return null;
  }

  bool get _isValid => !_windowClosed && _errorMessage == null && _enteredPrice != null;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _formatCloseDateTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_months[dt.month - 1]} ${dt.day}, $hour12:$minute $period';
  }

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _handleListTicket() async {
    final price = _enteredPrice;
    if (!_isValid || price == null) return;
    setState(() => _isSubmitting = true);
    // TODO: replace with a real Cloud Function call that creates the
    // RESALE_LISTINGS record and holds the ticket's QR code pending
    // reissuance to a buyer once the resale backend is wired up.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final listedTicket = widget.ticket.copyWith(status: TicketStatus.listed, resalePrice: price);
    final index = sampleMyTickets.indexWhere((t) => t.id == widget.ticket.id);
    if (index != -1) {
      sampleMyTickets[index] = listedTicket;
    }

    setState(() => _isSubmitting = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResaleConfirmationScreen(ticket: listedTicket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final event = ticket.event;
    final error = _errorMessage;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'List for Resale',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.inputBorderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ticket.tier.name,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.warning),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Original Price', style: AppTextStyles.bodyMuted),
                  const SizedBox(height: 4),
                  Text(
                    formatPeso(ticket.tier.price),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (_windowClosed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.event_busy_rounded, size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Resale listings for this event have closed. Listings automatically close 24 hours before the event starts.',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.error, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            const Text('Resale Price', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: _windowClosed ? AppColors.inputFillLight : AppColors.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: error != null ? AppColors.error : AppColors.inputBorderLight, width: 1.4),
              ),
              child: TextField(
                controller: _priceController,
                enabled: !_windowClosed,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: error != null ? AppColors.error : AppColors.textDark,
                ),
                cursorColor: AppColors.accentPurple,
                decoration: InputDecoration(
                  prefixText: '\u20b1',
                  prefixStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: error != null ? AppColors.error : AppColors.textDark,
                  ),
                  hintText: '0.00',
                  hintStyle: AppTextStyles.fieldInputLight.copyWith(color: AppColors.textMuted),
                  suffixIcon: _priceController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                          onPressed: () => setState(() => _priceController.clear()),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 17, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.error, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              _windowClosed
                  ? 'This event has already reached its resale cutoff.'
                  : 'Enter a price within the allowed range to continue. This listing will automatically close on ${_formatCloseDateTime(event.resaleListingCloseTime)} — 24 hours before the event — and any unsold ticket will be returned to you.',
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 26),
            GradientPillButton(
              label: 'List Ticket',
              loading: _isSubmitting,
              onPressed: _isValid ? _handleListTicket : null,
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentPurple),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
