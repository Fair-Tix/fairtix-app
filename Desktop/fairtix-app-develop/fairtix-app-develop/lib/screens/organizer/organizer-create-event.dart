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

class _UploadedDocument {
  final String name;
  final Uint8List bytes;
  final String extension;

  const _UploadedDocument({
    required this.name,
    required this.bytes,
    required this.extension,
  });
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

  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _bannerBytes;
  String? _bannerFileName;
  final List<_UploadedDocument> _supportingDocuments = [];
  bool _bannerUploaded = false;
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

  Future<void> _pickBannerImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _bannerBytes = bytes;
      _bannerFileName = picked.name;
      _bannerUploaded = true;
    });
  }

  Future<void> _pickSupportingDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.where((file) => file.bytes != null).map((file) {
      final filename = file.name;
      final extension = (file.extension ?? '')
          .replaceFirst('.', '')
          .toLowerCase();
      return _UploadedDocument(
        name: filename,
        bytes: file.bytes!,
        extension: extension,
      );
    }).toList();

    if (picked.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _supportingDocuments.addAll(picked);
    });
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

      if (_bannerBytes != null && _bannerFileName != null) {
        await EventRepository.instance.uploadEventBanner(
          eventId: event.id,
          bytes: _bannerBytes!,
          fileName: _bannerFileName!,
        );
      }

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

      if (_bannerBytes != null && _bannerFileName != null) {
        await EventRepository.instance.uploadEventBanner(
          eventId: event.id,
          bytes: _bannerBytes!,
          fileName: _bannerFileName!,
        );
      }

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
            onTap: _isSubmitting ? null : _pickBannerImage,
            borderRadius: BorderRadius.circular(10),
            child: _bannerBytes != null
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryPurple.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryPurple.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            image: DecorationImage(
                              image: MemoryImage(_bannerBytes!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bannerFileName ?? 'Selected image',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Change Image',
                                style: AppTextStyles.bodyGray.copyWith(
                                  fontSize: 12,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ],
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
              if (_supportingDocuments.isNotEmpty)
                ..._supportingDocuments.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc.name, style: AppTextStyles.label),
                                Text(
                                  'Uploaded: ${doc.extension.isEmpty ? 'file' : doc.extension.toUpperCase()} • ${doc.bytes.length ~/ 1024} KB',
                                  style: AppTextStyles.bodyGray.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Text(
                  'No document uploaded yet.',
                  style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
                ),
              const SizedBox(height: 12),
              OutlineButtonWidget(
                label: 'Upload Supporting Documents',
                onPressed: _isSubmitting ? null : _pickSupportingDocuments,
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
