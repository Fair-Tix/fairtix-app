import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

class PickedDocument {
  final Uint8List bytes;
  final String fileName;

  const PickedDocument({required this.bytes, required this.fileName});
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
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Single-Day (one event_start_date) vs Multi-Day (a run of generated
  // per-day sub-events between a start and end date — see
  // EventRepository.createEvent). Defaults to Single-Day since that's the
  // common case.
  EventSpan _span = EventSpan.singleDay;
  DateTime? _startDate;
  DateTime? _endDate;

  // Starts with a single blank tier - the organizer fills in real values;
  // no sample tier name/price/quantity is pre-populated.
  final List<TicketTierInput> _tiers = [TicketTierInput()];

  // Event banner: picked locally, then uploaded to the `event_banners`
  // bucket right after the event row exists (EventRepository.uploadEventBanner
  // needs a real event_id — see the policy comment there).
  Uint8List? _bannerBytes;
  String? _bannerExt;

  // Supporting documents (venue contract, LGU permit, etc.) — same
  // upload-after-create flow as the banner, via
  // EventRepository.uploadEventDocument.
  final List<PickedDocument> _documents = [];

  String? _formError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _eventNameController.dispose();
    _dateController.dispose();
    _endDateController.dispose();
    _venueController.dispose();
    _descriptionController.dispose();
    for (final tier in _tiers) {
      tier.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  Future<void> _pickBanner() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    if (!mounted) return;
    setState(() {
      _bannerBytes = bytes;
      _bannerExt = ext;
    });
  }

  Future<void> _pickDocuments() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    final picked = result.files
        .where((f) => f.bytes != null)
        .map((f) => PickedDocument(bytes: f.bytes!, fileName: f.name))
        .toList();
    if (picked.isEmpty) return;
    setState(() => _documents.addAll(picked));
  }

  /// Uploads whatever banner/documents were picked for the just-created
  /// [event]. Failures here are shown as a warning but never block
  /// navigation — the event itself was already created successfully.
  Future<void> _uploadAttachments(OrganizerEvent event) async {
    try {
      if (_bannerBytes != null) {
        await EventRepository.instance.uploadEventBanner(
          eventId: event.id,
          bytes: _bannerBytes!,
          fileExtension: _bannerExt ?? 'jpg',
        );
      }
      for (final doc in _documents) {
        await EventRepository.instance.uploadEventDocument(
          eventId: event.id,
          bytes: doc.bytes,
          fileName: doc.fileName,
        );
      }
    } on EventRepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${event.name}" was created, but ${e.message.toLowerCase()}',
          ),
        ),
      );
    }
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
        _venueController.text.trim().isEmpty) {
      setState(() => _formError = 'Event name and venue are required.');
      return false;
    }
    if (_span == EventSpan.singleDay) {
      if (_startDate == null) {
        setState(() => _formError = 'Pick a date for the event.');
        return false;
      }
    } else {
      if (_startDate == null || _endDate == null) {
        setState(() => _formError = 'Pick both a start date and an end date.');
        return false;
      }
      if (!_endDate!.isAfter(_startDate!)) {
        setState(
          () => _formError = 'The end date must be after the start date.',
        );
        return false;
      }
    }
    for (final tier in _tiers) {
      if (tier.nameController.text.trim().isEmpty ||
          tier.priceController.text.trim().isEmpty ||
          tier.quantityController.text.trim().isEmpty) {
        setState(
          () =>
              _formError = 'Fill in every ticket tier, or remove unused ones.',
        );
        return false;
      }
      if (double.tryParse(tier.priceController.text.trim()) == null ||
          int.tryParse(tier.quantityController.text.trim()) == null) {
        setState(
          () => _formError = 'Ticket price and quantity must be valid numbers.',
        );
        return false;
      }
    }
    setState(() => _formError = null);
    return true;
  }

  Future<void> _saveDraft() async {
    if (_eventNameController.text.trim().isEmpty) {
      setState(
        () =>
            _formError = 'Give your event a name before saving it as a draft.',
      );
      return;
    }
    if (_startDate == null) {
      setState(() => _formError = 'Pick a date before saving it as a draft.');
      return;
    }
    if (_span == EventSpan.multiDay &&
        (_endDate == null || !_endDate!.isAfter(_startDate!))) {
      setState(
        () => _formError =
            'Pick a valid end date (after the start date) before saving.',
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _formError = null;
    });
    try {
      final event = await EventRepository.instance.createEvent(
        name: _eventNameController.text.trim(),
        venue: _venueController.text.trim(),
        description: _descriptionController.text.trim(),
        span: _span,
        startDate: _startDate!,
        endDate: _span == EventSpan.multiDay ? _endDate : null,
        status: EventStatus.draft,
        tiers: _buildTiers(),
      );
      await _uploadAttachments(event);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${event.name}" saved as a draft.')),
      );
      Navigator.pop(context);
    } on EventRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  List<TicketTier> _buildTiers() {
    return _tiers
        .where(
          (t) =>
              t.nameController.text.trim().isNotEmpty &&
              double.tryParse(t.priceController.text.trim()) != null &&
              int.tryParse(t.quantityController.text.trim()) != null,
        )
        .map(
          (t) => TicketTier(
            name: t.nameController.text.trim(),
            price: double.parse(t.priceController.text.trim()),
            quantity: int.parse(t.quantityController.text.trim()),
          ),
        )
        .toList();
  }

  Future<void> _publishEvent() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final event = await EventRepository.instance.createEvent(
        name: _eventNameController.text.trim(),
        venue: _venueController.text.trim(),
        description: _descriptionController.text.trim(),
        span: _span,
        startDate: _startDate!,
        endDate: _span == EventSpan.multiDay ? _endDate : null,
        status: EventStatus.published,
        tiers: _buildTiers(),
      );

      await _uploadAttachments(event);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrganizerEventCreatedScreen(
            eventName: event.name,
            date: event.date,
            venue: event.venue,
            isMultiDay: event.isMultiDay,
          ),
        ),
      );
    } on EventRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textDark),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isSubmitting ? null : _saveDraft,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                  side: const BorderSide(color: AppColors.primaryPurple),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save as Draft'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _publishEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publish Event'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datePickerField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<DateTime> onPicked,
    required DateTime firstDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          enabled: !_isSubmitting,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: firstDate,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            if (date != null) onPicked(date);
          },
          decoration: InputDecoration(
            hintText: 'Select Date',
            hintStyle: AppTextStyles.bodyGray,
            prefixIcon: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: AppColors.textGray,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
      ],
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
              const Text('Event Duration *', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Single-Day'),
                      selected: _span == EventSpan.singleDay,
                      onSelected: _isSubmitting
                          ? null
                          : (_) => setState(() {
                              _span = EventSpan.singleDay;
                              _endDate = null;
                              _endDateController.clear();
                            }),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _span == EventSpan.singleDay
                            ? Colors.white
                            : AppColors.textGray,
                      ),
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: const Color(0xFFF0EEFA),
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Multi-Day'),
                      selected: _span == EventSpan.multiDay,
                      onSelected: _isSubmitting
                          ? null
                          : (_) => setState(() => _span = EventSpan.multiDay),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _span == EventSpan.multiDay
                            ? Colors.white
                            : AppColors.textGray,
                      ),
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: const Color(0xFFF0EEFA),
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                  ),
                ],
              ),
              if (_span == EventSpan.multiDay) ...[
                const SizedBox(height: 4),
                Text(
                  'One event page is generated per day, each with its own '
                  'ticket inventory.',
                  style: AppTextStyles.bodyGray.copyWith(fontSize: 11),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _datePickerField(
                      label: _span == EventSpan.singleDay
                          ? 'Date *'
                          : 'Start Date *',
                      controller: _dateController,
                      onPicked: (date) {
                        setState(() {
                          _startDate = date;
                          _dateController.text = _formatDate(date);
                        });
                      },
                      firstDate: DateTime.now(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _span == EventSpan.multiDay
                        ? _datePickerField(
                            label: 'End Date *',
                            controller: _endDateController,
                            onPicked: (date) {
                              setState(() {
                                _endDate = date;
                                _endDateController.text = _formatDate(date);
                              });
                            },
                            firstDate: _startDate ?? DateTime.now(),
                          )
                        : AppTextField(
                            label: 'Venue *',
                            hint: 'Arena, Hotel, or Stadium',
                            controller: _venueController,
                            prefixIcon: const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.textGray,
                            ),
                          ),
                  ),
                ],
              ),
              if (_span == EventSpan.multiDay) ...[
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Venue *',
                  hint: 'Arena, Hotel, or Stadium',
                  controller: _venueController,
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.textGray,
                  ),
                ),
              ],
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Ticket Tiers',
          headerTrailing: TextButton.icon(
            onPressed: _addTier,
            icon: const Icon(
              Icons.add,
              size: 16,
              color: AppColors.primaryPurple,
            ),
            label: const Text(
              '+ Add New Tier',
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
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
                      onPressed: _tiers.length > 1
                          ? () => _removeTier(index)
                          : null,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.dangerRed,
                      ),
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
            onTap: _isSubmitting ? null : _pickBanner,
            borderRadius: BorderRadius.circular(10),
            child: _bannerBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.memory(
                          _bannerBytes!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          height: 150,
                          width: double.infinity,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        const Text(
                          'Change Image',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryPurple.withValues(alpha: 0.4),
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: AppColors.primaryPurple,
                          size: 30,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Upload Image',
                          style: TextStyle(
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
              if (_documents.isEmpty)
                Text(
                  'No documents uploaded yet.',
                  style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
                )
              else
                for (var i = 0; i < _documents.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: AppColors.textGray,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _documents[i].fileName,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label,
                          ),
                        ),
                        InkWell(
                          onTap: _isSubmitting
                              ? null
                              : () => setState(() => _documents.removeAt(i)),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.dangerRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 2),
              OutlineButtonWidget(
                label: 'Add Document',
                onPressed: _isSubmitting ? null : _pickDocuments,
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
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryPurple,
                ),
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
