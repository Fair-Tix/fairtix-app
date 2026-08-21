import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-event-edited.dart';
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

  late List<EditTierInput> _tiers;
  OrganizerEvent? _event;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _event = EventRepository.instance.getById(widget.eventId);

    _eventNameController = TextEditingController(text: _event?.name ?? '');
    _dateController = TextEditingController(text: _event?.date ?? '');
    _venueController = TextEditingController(text: _event?.venue ?? '');
    _descriptionController =
        TextEditingController(text: _event?.description ?? '');

    final tiers = _event?.tiers ?? const [];
    _tiers = tiers.isEmpty
        ? [EditTierInput()]
        : tiers
            .map((t) => EditTierInput(
                  name: t.name,
                  price: t.price % 1 == 0
                      ? t.price.toStringAsFixed(0)
                      : t.price.toString(),
                  quantity: t.quantity.toString(),
                ))
            .toList();
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
    if (_eventNameController.text.trim().isEmpty ||
        _dateController.text.trim().isEmpty ||
        _venueController.text.trim().isEmpty) {
      setState(() => _formError =
          'Event name, date & time, and venue are required.');
      return false;
    }
    for (final tier in _tiers) {
      if (tier.nameController.text.trim().isEmpty ||
          double.tryParse(tier.priceController.text.trim()) == null ||
          int.tryParse(tier.quantityController.text.trim()) == null) {
        setState(() => _formError =
            'Fill in a valid name, price, and quantity for every ticket tier.');
        return false;
      }
    }
    setState(() => _formError = null);
    return true;
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text(
          'This action cannot be undone. All ticket sales data associated '
          'with this event will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final eventName = _event?.name ?? 'This event';
              EventRepository.instance.deleteEvent(widget.eventId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$eventName" has been deleted.')),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrganizerMyEventsScreen(),
                ),
              );
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.dangerRed)),
          ),
        ],
      ),
    );
  }

  void _saveChanges() {
    if (_event == null) {
      Navigator.pop(context);
      return;
    }
    if (!_validate()) return;

    final updatedTiers = _tiers
        .map((t) => TicketTier(
              name: t.nameController.text.trim(),
              price: double.parse(t.priceController.text.trim()),
              quantity: int.parse(t.quantityController.text.trim()),
              sold: _event!.tiers
                  .where((existing) => existing.name == t.nameController.text.trim())
                  .fold(0, (sum, existing) => sum + existing.sold),
            ))
        .toList();

    final updated = _event!.copyWith(
      name: _eventNameController.text.trim(),
      date: _dateController.text.trim(),
      venue: _venueController.text.trim(),
      description: _descriptionController.text.trim(),
      tiers: updatedTiers,
    );
    EventRepository.instance.updateEvent(updated);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerEventEditedScreen(eventName: updated.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _leftColumn()),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _rightColumn()),
                    ],
                  ),
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
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Update Event'),
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
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Date & Time *',
                      hint: 'Select Date',
                      controller: _dateController,
                      prefixIcon: const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.textGray),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppTextField(
                      label: 'Venue *',
                      hint: 'Arena, Hotel, or Stadium',
                      controller: _venueController,
                      prefixIcon: const Icon(Icons.location_on_outlined,
                          size: 18, color: AppColors.textGray),
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
                      child: AppTextField(
                        label: 'Tier Name',
                        hint: 'Tier name',
                        controller: tier.nameController,
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
                  color: AppColors.primaryPurple.withOpacity(0.15),
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
                        color: Colors.black.withOpacity(0.35),
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
            'No supporting documents uploaded yet.',
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
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
