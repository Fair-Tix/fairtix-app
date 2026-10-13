import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-event-created.dart';
import 'organizer-form-widgets.dart';

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

  // Per-field warnings, keyed by field ('name', 'venue', 'start', 'end',
  // 'documents', 'tiers', 'tier<i>.name' / '.price' / '.quantity'). A
  // warning is cleared as soon as the organizer edits that field.
  final Map<String, String> _errors = {};

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

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
    setState(() {
      _documents.addAll(picked);
      _errors.remove('documents');
    });
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
      _errors.removeWhere((k, _) => k.startsWith('tier'));
    });
  }

  /// Validates every field and records a warning under each bad one.
  /// [forPublish] additionally requires venue, tiers and supporting
  /// documents (drafts only need a name and date).
  bool _validate({bool forPublish = true}) {
    final errors = <String, String>{};

    if (_eventNameController.text.trim().isEmpty) {
      errors['name'] = 'Event name is required.';
    }
    if (_startDate == null) {
      errors['start'] = _span == EventSpan.singleDay
          ? 'Pick a date for the event.'
          : 'Pick a start date.';
    }
    if (_span == EventSpan.multiDay) {
      if (_endDate == null) {
        errors['end'] = 'Pick an end date.';
      } else if (_startDate != null && !_endDate!.isAfter(_startDate!)) {
        errors['end'] = 'End date must be after the start date.';
      }
    }

    if (forPublish) {
      if (_venueController.text.trim().isEmpty) {
        errors['venue'] = 'Search and pick a venue.';
      }
      if (_documents.isEmpty) {
        errors['documents'] =
            'Upload at least one supporting document (venue contract, permit, etc.).';
      }
      if (_tiers.isEmpty) {
        errors['tiers'] = 'Add at least one ticket tier.';
      }
      for (var i = 0; i < _tiers.length; i++) {
        final tier = _tiers[i];
        if (tier.nameController.text.trim().isEmpty) {
          errors['tier$i.name'] = 'Choose a tier.';
        }
        final price = double.tryParse(tier.priceController.text.trim());
        if (tier.priceController.text.trim().isEmpty) {
          errors['tier$i.price'] = 'Price is required.';
        } else if (price == null || price < 0) {
          errors['tier$i.price'] = 'Enter a valid price.';
        }
        final qty = int.tryParse(tier.quantityController.text.trim());
        if (tier.quantityController.text.trim().isEmpty) {
          errors['tier$i.quantity'] = 'Quantity is required.';
        } else if (qty == null || qty <= 0) {
          errors['tier$i.quantity'] = 'Enter a whole number above 0.';
        }
      }
      final names = _tiers
          .map((t) => t.nameController.text.trim().toLowerCase())
          .where((n) => n.isNotEmpty)
          .toList();
      for (var i = 0; i < _tiers.length; i++) {
        final n = _tiers[i].nameController.text.trim().toLowerCase();
        if (n.isNotEmpty && names.where((x) => x == n).length > 1) {
          errors['tier$i.name'] = 'Each tier must have a different name.';
        }
      }
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _formError = errors.isEmpty
          ? null
          : 'Please fix the ${errors.length} highlighted '
                'field${errors.length == 1 ? '' : 's'} below.';
    });
    return errors.isEmpty;
  }

  Future<void> _saveDraft() async {
    if (!_validate(forPublish: false)) return;
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
    String? errorKey,
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
            if (date != null) {
              onPicked(date);
              if (errorKey != null) _clearError(errorKey);
            }
          },
          decoration: InputDecoration(
            hintText: 'Select Date',
            hintStyle: AppTextStyles.bodyGray,
            errorText: errorKey == null ? null : _errors[errorKey],
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
                errorText: _errors['name'],
                onChanged: (_) => _clearError('name'),
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
                      errorKey: 'start',
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
                            errorKey: 'end',
                          )
                        : VenueDropdownField(
                            controller: _venueController,
                            enabled: !_isSubmitting,
                            errorText: _errors['venue'],
                            onChanged: (_) => _clearError('venue'),
                          ),
                  ),
                ],
              ),
              if (_span == EventSpan.multiDay) ...[
                const SizedBox(height: 18),
                VenueDropdownField(
                  controller: _venueController,
                  enabled: !_isSubmitting,
                  errorText: _errors['venue'],
                  onChanged: (_) => _clearError('venue'),
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
            children: [
              FieldWarning(_errors['tiers']),
              ...List.generate(_tiers.length, (index) {
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
                        hint: '2500',
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
                        hint: '200',
                        controller: tier.quantityController,
                        keyboardType: TextInputType.number,
                        errorText: _errors['tier$index.quantity'],
                        onChanged: (_) => _clearError('tier$index.quantity'),
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
            ],
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
          title: 'Supporting Documents *',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_documents.isEmpty)
                Text(
                  'Required to publish: venue contract, permit, or other proof.',
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
              FieldWarning(_errors['documents']),
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
