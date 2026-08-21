import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-event-created.dart';

class TicketTierInput {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;

  TicketTierInput({String name = '', String price = '', String quantity = ''})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        quantityController = TextEditingController(text: quantity);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }
}

class OrganizerCreateEventScreen extends StatefulWidget {
  const OrganizerCreateEventScreen({super.key});

  @override
  State<OrganizerCreateEventScreen> createState() =>
      _OrganizerCreateEventScreenState();
}

class _OrganizerCreateEventScreenState
    extends State<OrganizerCreateEventScreen> {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();

  // Starts with a single blank tier - the organizer fills in real values;
  // no sample tier name/price/quantity is pre-populated.
  final List<TicketTierInput> _tiers = [TicketTierInput()];

  // TODO(backend): Replace these tap-to-simulate uploads with a real file
  // picker (e.g. the `file_picker` package) and upload to Firebase Storage.
  String? _permitFileName;
  bool _bannerUploaded = false;
  String? _formError;

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
    setState(() {
      _tiers.add(TicketTierInput());
    });
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
          tier.priceController.text.trim().isEmpty ||
          tier.quantityController.text.trim().isEmpty) {
        setState(() =>
            _formError = 'Fill in every ticket tier, or remove unused ones.');
        return false;
      }
      if (double.tryParse(tier.priceController.text.trim()) == null ||
          int.tryParse(tier.quantityController.text.trim()) == null) {
        setState(() => _formError =
            'Ticket price and quantity must be valid numbers.');
        return false;
      }
    }
    setState(() => _formError = null);
    return true;
  }

  void _saveDraft() {
    if (_eventNameController.text.trim().isEmpty) {
      setState(() => _formError =
          'Give your event a name before saving it as a draft.');
      return;
    }
    final event = EventRepository.instance.addEvent(
      name: _eventNameController.text.trim(),
      date: _dateController.text.trim(),
      venue: _venueController.text.trim(),
      description: _descriptionController.text.trim(),
      status: EventStatus.draft,
      tiers: _buildTiers(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${event.name}" saved as a draft.')),
    );
    Navigator.pop(context);
  }

  List<TicketTier> _buildTiers() {
    return _tiers
        .where((t) =>
            t.nameController.text.trim().isNotEmpty &&
            double.tryParse(t.priceController.text.trim()) != null &&
            int.tryParse(t.quantityController.text.trim()) != null)
        .map((t) => TicketTier(
              name: t.nameController.text.trim(),
              price: double.parse(t.priceController.text.trim()),
              quantity: int.parse(t.quantityController.text.trim()),
            ))
        .toList();
  }

  void _publishEvent() {
    if (!_validate()) return;

    final event = EventRepository.instance.addEvent(
      name: _eventNameController.text.trim(),
      date: _dateController.text.trim(),
      venue: _venueController.text.trim(),
      description: _descriptionController.text.trim(),
      status: EventStatus.published,
      tiers: _buildTiers(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerEventCreatedScreen(
          eventName: event.name,
          date: event.date,
          venue: event.venue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1000;

    return OrganizerScaffold(
      pageTitle: 'Create New Event',
      activeItem: OrganizerNavItem.dashboard,
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textDark)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _saveDraft,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                  side: const BorderSide(color: AppColors.primaryPurple),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save as Draft'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _publishEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Publish Event'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date & Time *', style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _dateController,
                          readOnly: true,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              _dateController.text =
                                  '${date.month}/${date.day}/${date.year}';
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Select Date',
                            hintStyle: AppTextStyles.bodyGray,
                            prefixIcon: const Icon(Icons.calendar_today_outlined,
                                size: 18, color: AppColors.textGray),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
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
                      hintText: 'Tell attendees about your event...',
                      hintStyle: AppTextStyles.bodyGray,
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
              style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w600),
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
                        hint: 'VIP Standing',
                        controller: tier.nameController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Price (\u20B1)',
                        hint: '2500',
                        controller: tier.priceController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Quantity',
                        hint: '200',
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
          child: InkWell(
            onTap: () => setState(() => _bannerUploaded = true),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryPurple.withOpacity(0.4),
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_outlined,
                      color: AppColors.primaryPurple, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    _bannerUploaded ? 'Image Selected' : 'Upload Image',
                    style: const TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '16:9 aspect ratio recommended',
                    style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Supporting Documents',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_permitFileName != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image_outlined,
                          size: 18, color: AppColors.textGray),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Proof of Venue Booking',
                                style: AppTextStyles.label),
                            Text(
                              _permitFileName!,
                              style: AppTextStyles.bodyGray
                                  .copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'No document uploaded yet.',
                  style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
                ),
              const SizedBox(height: 12),
              OutlineButtonWidget(
                label: 'Upload Permit',
                onPressed: () {
                  // TODO(backend): open a real file picker and upload the
                  // selected document to Storage.
                  setState(() {
                    _permitFileName = 'Document selected';
                  });
                },
                height: 48,
              ),
            ],
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
