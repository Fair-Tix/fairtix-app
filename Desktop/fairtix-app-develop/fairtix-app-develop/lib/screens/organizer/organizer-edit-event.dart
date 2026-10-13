import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-event-edited.dart';
import 'organizer-form-widgets.dart';
import 'organizer-my-events.dart';

class EditTierInput {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;

  EditTierInput({String name = '', String price = '', String quantity = ''})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        quantityController = TextEditingController(text: quantity);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }
}

class OrganizerEditEventScreen extends StatefulWidget {
  final String eventId;

  const OrganizerEditEventScreen({super.key, required this.eventId});

  @override
  State<OrganizerEditEventScreen> createState() =>
      _OrganizerEditEventScreenState();
}

class _OrganizerEditEventScreenState extends State<OrganizerEditEventScreen> {
  late final TextEditingController _eventNameController;
  late final TextEditingController _dateController;
  late final TextEditingController _venueController;
  late final TextEditingController _descriptionController;

  List<EditTierInput> _tiers = [];
  OrganizerEvent? _event;
  String? _formError;
  bool _isLoading = true;
  bool _isSaving = false;
  final Map<String, String> _errors = {};

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  @override
  void initState() {
    super.initState();
    _eventNameController = TextEditingController();
    _dateController = TextEditingController();
    _venueController = TextEditingController();
    _descriptionController = TextEditingController();
    _load();
  }

  /// Always pulls fresh rows before showing the form, with a spinner while
  /// loading and a retry state on failure. Opening Manage on a just-saved
  /// draft used to build against an empty/stale cache and a heavy
  /// IntrinsicHeight layout, which is what made the page hang.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _formError = null;
    });
    try {
      await EventRepository.instance.refresh();
    } on EventRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = e.message;
        _isLoading = false;
      });
      return;
    }
    if (!mounted) return;
    final event = EventRepository.instance.getById(widget.eventId);
    for (final t in _tiers) {
      t.dispose();
    }
    _event = event;
    _eventNameController.text = event?.name ?? '';
    _dateController.text = event?.date ?? '';
    _venueController.text = event?.venue ?? '';
    _descriptionController.text = event?.description ?? '';
    final tiers = event?.tiers ?? const <TicketTier>[];
    _tiers = tiers.isEmpty
        ? [EditTierInput()]
        : tiers.map((t) {
            // Multi-day parents roll their days up; show the per-day figure.
            final perDay = (event!.isMultiDay && event.dayCount > 0)
                ? t.quantity ~/ event.dayCount
                : t.quantity;
            return EditTierInput(
              name: t.name,
              price: t.price % 1 == 0
                  ? t.price.toStringAsFixed(0)
                  : t.price.toString(),
              quantity: perDay.toString(),
            );
          }).toList();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _dateController.dispose();
    _venueController.dispose();
    _descriptionController.dispose();
    for (final tier in _tiers) {
      tier.dispose();
    }
    super.dispose();
  }

  void _addTier() {
    setState(() => _tiers.add(EditTierInput()));
  }

  void _removeTier(int index) {
    setState(() {
      _tiers[index].dispose();
      _tiers.removeAt(index);
    });
  }

  bool _validate() {
    final errors = <String, String>{};
    if (_eventNameController.text.trim().isEmpty) {
      errors['name'] = 'Event name is required.';
    }
    if (_venueController.text.trim().isEmpty) {
      errors['venue'] = 'Search and pick a venue.';
    }
    for (var i = 0; i < _tiers.length; i++) {
      final t = _tiers[i];
      if (t.nameController.text.trim().isEmpty) {
        errors['tier$i.name'] = 'Choose a tier.';
      }
      final price = double.tryParse(t.priceController.text.trim());
      if (price == null || price < 0) {
        errors['tier$i.price'] = 'Enter a valid price.';
      }
      final qty = int.tryParse(t.quantityController.text.trim());
      if (qty == null || qty <= 0) {
        errors['tier$i.quantity'] = 'Whole number above 0.';
      }
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _formError = errors.isEmpty
          ? null
          : 'Please fix the highlighted field${errors.length == 1 ? '' : 's'}.';
    });
    return errors.isEmpty;
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text(
          'This action cannot be undone. Events that already have ticket '
          'sales cannot be deleted - cancel them instead so buyers are '
          'refunded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final eventName = _event?.name ?? 'This event';
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              Navigator.pop(ctx);
              try {
                await EventRepository.instance.deleteEvent(widget.eventId);
              } on EventRepositoryException catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.message)));
                return;
              }
              messenger.showSnackBar(
                SnackBar(content: Text('"$eventName" has been deleted.')),
              );
              if (!navigator.mounted) return;
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const OrganizerMyEventsScreen(),
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges({bool publish = false}) async {
    if (_event == null) {
      Navigator.pop(context);
      return;
    }
    if (!_validate()) return;

    final updatedTiers = _tiers
        .map(
          (t) => TicketTier(
            name: t.nameController.text.trim(),
            price: double.parse(t.priceController.text.trim()),
            quantity: int.parse(t.quantityController.text.trim()),
          ),
        )
        .toList();

    final updated = _event!.copyWith(
      name: _eventNameController.text.trim(),
      venue: _venueController.text.trim(),
      description: _descriptionController.text.trim(),
      tiers: updatedTiers,
    );

    setState(() {
      _isSaving = true;
      _formError = null;
    });
    try {
      await EventRepository.instance.updateEvent(updated, publish: publish);
    } on EventRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = e.message;
        _isSaving = false;
      });
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerEventEditedScreen(eventName: updated.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const OrganizerScaffold(
        pageTitle: 'Edit Event',
        activeItem: OrganizerNavItem.myEvents,
        body: Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }
    if (_event == null && _formError != null) {
      return OrganizerScaffold(
        pageTitle: 'Edit Event',
        activeItem: OrganizerNavItem.myEvents,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: AppColors.dangerRed),
              const SizedBox(height: 12),
              Text(_formError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.dangerRed)),
              const SizedBox(height: 16),
              OutlineButtonWidget(label: 'Retry', onPressed: _load),
            ],
          ),
        ),
      );
    }
    if (_event == null) {
      return OrganizerScaffold(
        pageTitle: 'Edit Event',
        activeItem: OrganizerNavItem.myEvents,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: AppColors.textGray),
              const SizedBox(height: 12),
              const Text('This event could not be found.',
                  style: AppTextStyles.h3),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1000;

    return OrganizerScaffold(
      pageTitle: 'Edit Event',
      activeItem: OrganizerNavItem.myEvents,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isWide
              // No IntrinsicHeight here: the form contains autocomplete /
              // dropdown overlays whose intrinsic-size pass can stall layout
              // (this is what made the Manage page hang on drafts).
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _leftColumn()),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: _rightColumn()),
                  ],
                )
              : Column(
                  children: [
                    _leftColumn(),
                    const SizedBox(height: 24),
                    _rightColumn(),
                  ],
                ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            Text(
              _formError!,
              style: const TextStyle(
                color: AppColors.dangerRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              OutlineButtonWidget(
                label: 'Delete Event',
                borderColor: AppColors.dangerRed,
                textColor: AppColors.dangerRed,
                height: 48,
                onPressed: _confirmDelete,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel Changes',
                    style: TextStyle(color: AppColors.textDark)),
              ),
              const SizedBox(width: 12),
              if (_event!.status == EventStatus.draft) ...[
                OutlinedButton(
                  onPressed: _isSaving ? null : () => _saveChanges(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: const BorderSide(color: AppColors.primaryPurple),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save Draft'),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () => _saveChanges(
                          publish: _event!.status == EventStatus.draft,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_event!.status == EventStatus.draft
                        ? 'Publish Event'
                        : 'Update Event'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: 'General Information',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Event Name *',
                hint: 'e.g. BINI Signals World Tour',
                controller: _eventNameController,
                errorText: _errors['name'],
                onChanged: (_) => _clearError('name'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      // Dates are locked after creation: buyers, scanner
                      // sessions and per-day inventory are tied to them.
                      label: 'Date (locked)',
                      hint: '',
                      controller: _dateController,
                      enabled: false,
                      prefixIcon: const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.textGray),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: VenueDropdownField(
                      controller: _venueController,
                      enabled: !_isSaving,
                      errorText: _errors['venue'],
                      onChanged: (_) => _clearError('venue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Ticket Tiers',
          headerTrailing: TextButton.icon(
            onPressed: _addTier,
            icon: const Icon(Icons.add, size: 16, color: AppColors.primaryPurple),
            label: const Text(
              '+ Add New Tier',
              style: TextStyle(
                  color: AppColors.primaryPurple, fontWeight: FontWeight.w600),
            ),
          ),
          child: Column(
            children: List.generate(_tiers.length, (index) {
              final tier = _tiers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TierNameDropdown(
                        controller: tier.nameController,
                        errorText: _errors['tier$index.name'],
                        onChanged: (_) => _clearError('tier$index.name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Price (\u20B1)',
                        hint: '0',
                        controller: tier.priceController,
                        keyboardType: TextInputType.number,
                        errorText: _errors['tier$index.price'],
                        onChanged: (_) => _clearError('tier$index.price'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Quantity',
                        hint: '0',
                        controller: tier.quantityController,
                        keyboardType: TextInputType.number,
                        errorText: _errors['tier$index.quantity'],
                        onChanged: (_) => _clearError('tier$index.quantity'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          _tiers.length > 1 ? () => _removeTier(index) : null,
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.dangerRed),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _rightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: 'Event Banner',
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image, size: 48, color: Colors.white70),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Banner image upload is not connected yet.'),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Change Image',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Supporting Documents',
          child: Text(
            (_event?.supportingDocumentUrls.isEmpty ?? true)
                ? 'No supporting documents uploaded yet.'
                : '${_event!.supportingDocumentUrls.length} document'
                    '${_event!.supportingDocumentUrls.length == 1 ? '' : 's'} on file.',
            style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    Widget? headerTrailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.h3.copyWith(color: AppColors.primaryPurple),
              ),
              ?headerTrailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
