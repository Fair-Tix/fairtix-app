import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-event-cancelled.dart';
import 'organizer-my-events.dart';

/// Cancel a whole event, or - for a multi-day run - just one day.
///
/// "Confirm Cancellation" calls `EventRepository.cancelEvent`, which runs the
/// `cancel_event` RPC (supabase/organizer_event_functions.sql): the event(s)
/// are marked canceled, current ticket holders' tickets are invalidated and
/// refunded, and each holder gets an in-app notification - all in one
/// transaction. Nothing changes unless that call succeeds.
class OrganizerCancelEventScreen extends StatefulWidget {
  final String eventId;

  const OrganizerCancelEventScreen({super.key, required this.eventId});

  @override
  State<OrganizerCancelEventScreen> createState() =>
      _OrganizerCancelEventScreenState();
}

class _OrganizerCancelEventScreenState
    extends State<OrganizerCancelEventScreen> {
  final TextEditingController _reasonController = TextEditingController();

  OrganizerEvent? _event;
  List<OrganizerEvent> _days = const [];
  // null = the whole event; otherwise the id of the single day to cancel.
  String? _selectedDayId;

  bool _isLoading = true;
  bool _isCancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await EventRepository.instance.refresh();
      final event = EventRepository.instance.getById(widget.eventId);
      var days = <OrganizerEvent>[];
      if (event != null && event.isMultiDay) {
        days = (await EventRepository.instance.fetchDays(event.id))
            .where((d) => d.status != EventStatus.cancelled)
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _event = event;
        _days = days;
        _isLoading = false;
      });
    } on EventRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  int get _ticketsAtStake {
    if (_selectedDayId != null) {
      for (final d in _days) {
        if (d.id == _selectedDayId) return d.ticketsSold;
      }
    }
    return _event?.ticketsSold ?? 0;
  }

  Future<void> _confirm() async {
    final event = _event;
    if (event == null) return;
    setState(() {
      _isCancelling = true;
      _error = null;
    });
    try {
      final result = await EventRepository.instance.cancelEvent(
        _selectedDayId ?? event.id,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      final n = result.ticketsRefunded;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrganizerEventCancelledScreen(
            eventId: event.id,
            totalRefunds:
                '$n Ticket${n == 1 ? '' : 's'} \u2022 '
                '\u20B1${result.amountRefunded.toStringAsFixed(2)}',
          ),
        ),
      );
    } on EventRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isCancelling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const OrganizerScaffold(
        pageTitle: 'Cancel Event',
        activeItem: OrganizerNavItem.myEvents,
        body: Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }

    final event = _event;
    if (event == null) {
      return OrganizerScaffold(
        pageTitle: 'Cancel Event',
        activeItem: OrganizerNavItem.myEvents,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.textGray,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? 'This event could not be found.',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlineButtonWidget(
                label: 'Back to My Events',
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizerMyEventsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return OrganizerScaffold(
      pageTitle: 'Cancel Event',
      activeItem: OrganizerNavItem.myEvents,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.dangerRedBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.dangerRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Cancel This Event?',
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'This action cannot be undone. All ticket holders will be '
                  'notified and refunds will be processed automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryPurple.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (event.isMultiDay && _days.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('What to cancel', style: AppTextStyles.label),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedDayId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Whole event (all days)'),
                      ),
                      for (final d in _days)
                        DropdownMenuItem<String?>(
                          value: d.id,
                          child: Text(
                            'Day ${d.dayNumber ?? ''} only \u2022 ${d.date}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _isCancelling
                        ? null
                        : (v) => setState(() => _selectedDayId = v),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Event', event.name),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: AppColors.borderLight),
                      ),
                      _infoRow('Venue', event.venue),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: AppColors.borderLight),
                      ),
                      _infoRow('Tickets to refund', '$_ticketsAtStake'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _reasonController,
                  enabled: !_isCancelling,
                  maxLines: 2,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Reason (optional)',
                    hintStyle: AppTextStyles.bodyGray,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.dangerRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _isCancelling
                    ? const SizedBox(
                        height: 48,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    : PrimaryButton(
                        label: _selectedDayId == null
                            ? 'Confirm Cancellation'
                            : 'Cancel This Day',
                        color: AppColors.dangerRed,
                        onPressed: _confirm,
                      ),
                const SizedBox(height: 12),
                OutlineButtonWidget(
                  label: 'Keep Event',
                  onPressed: _isCancelling ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyGray),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.label,
          ),
        ),
      ],
    );
  }
}
