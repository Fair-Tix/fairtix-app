import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/access_control.dart';
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
  bool _isUploadingDocs = false;
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
    // Editing an event needs a current subscription (the server enforces it
    // too). Explain up front and go back instead of showing a form that can't
    // be saved. Viewing events stays available from My Events.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final allowed = await ensureOrganizerAccess(
        context,
        OrganizerRequirement.subscription,
      );
      if (!allowed && mounted) Navigator.of(context).maybePop();
    });
  }

  /// Use the current event snapshot immediately when Manage is opened from a
  /// list that has already loaded it. A cold load is bounded and has a retry
  /// state so a slow backend cannot leave the editor stuck on its spinner.
  Future<void> _load() async {
    final cachedEvent = EventRepository.instance.getById(widget.eventId);
    if (cachedEvent != null) {
      _populateEvent(cachedEvent);
      setState(() {
        _isLoading = false;
        _formError = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _formError = null;
    });
    try {
      await EventRepository.instance.refresh().timeout(
        const Duration(seconds: 15),
      );
    } on EventRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = e.message;
        _isLoading = false;
      });
      return;
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _formError = 'Loading this event took too long. Please try again.';
        _isLoading = false;
      });
      return;
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = 'Could not load this event: $e';
        _isLoading = false;
      });
      return;
    }
    if (!mounted) return;
    final event = EventRepository.instance.getById(widget.eventId);
    if (event != null) _populateEvent(event);
    setState(() {
      _formError = event == null ? 'This event could not be found.' : null;
      _isLoading = false;
    });
  }

  void _populateEvent(OrganizerEvent event) {
    for (final t in _tiers) {
      t.dispose();
    }
    _event = event;
    _eventNameController.text = event.name;
    _dateController.text = event.date;
    _venueController.text = event.venue;
    _descriptionController.text = event.description;
    _tiers = event.tiers.isEmpty
        ? [EditTierInput()]
        : event.tiers.map((t) {
            // Multi-day parents roll their days up; show the per-day figure.
            final perDay = (event.isMultiDay && event.dayCount > 0)
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

  /// Lets the organizer attach supporting documents from the Manage page,
  /// mainly after an admin unpublished the event and asked for new ones.
  /// The admin is notified and republishes once the documents are valid.
  Future<void> _uploadDocuments() async {
    if (_event == null || _isUploadingDocs) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
    } catch (err) {
      debugPrint('Upload Documents: file picker failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the file picker: $err')),
      );
      return;
    }
    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploadingDocs = true);
    String message;
    var uploaded = 0;
    try {
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        await EventRepository.instance.uploadEventDocument(
          eventId: _event!.id,
          bytes: bytes,
          fileName: f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_'),
        );
        uploaded++;
      }
      message = uploaded == 0
          ? 'Could not read the selected file(s). Please try again.'
          : (_event!.isUnpublishedByAdmin
                ? 'Documents submitted. An admin will review them and republish your event.'
                : 'Documents uploaded.');
    } on EventRepositoryException catch (err) {
      message = err.message;
    } catch (err) {
      debugPrint('Upload Documents failed: $err');
      message = 'Could not upload the document: $err';
    }
    if (!mounted) return;
    // Refresh only the snapshot (status / document count); don't overwrite
    // whatever the organizer has typed into the form.
    final fresh = EventRepository.instance.getById(widget.eventId);
    setState(() {
      if (fresh != null) _event = fresh;
      _isUploadingDocs = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDeadline(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
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
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.dangerRed,
              ),
              const SizedBox(height: 12),
              Text(
                _formError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.dangerRed),
              ),
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
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.textGray,
              ),
              const SizedBox(height: 12),
              const Text(
                'This event could not be found.',
                style: AppTextStyles.h3,
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1400;

    return OrganizerScaffold(
      pageTitle: 'Edit Event',
      activeItem: OrganizerNavItem.myEvents,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isWide
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
          LayoutBuilder(
            builder: (context, constraints) {
              final deleteButton = OutlineButtonWidget(
                label: 'Delete Event',
                borderColor: AppColors.dangerRed,
                textColor: AppColors.dangerRed,
                height: 48,
                onPressed: _confirmDelete,
              );
              final cancelButton = TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel Changes',
                  style: TextStyle(color: AppColors.textDark),
                ),
              );
              final draftButton = OutlinedButton(
                onPressed: _isSaving ? null : () => _saveChanges(),
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
                child: const Text('Save Draft'),
              );
              final saveButton = ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () => _saveChanges(
                        // Admin-unpublished events can only be republished
                        // by an admin, so never try to publish them here.
                        publish:
                            _event!.status == EventStatus.draft &&
                            !_event!.isUnpublishedByAdmin,
                      ),
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
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _event!.isUnpublishedByAdmin
                            ? 'Save Changes'
                            : _event!.status == EventStatus.draft
                            ? 'Publish Event'
                            : 'Update Event',
                      ),
              );
              final trailingButtons = [
                cancelButton,
                if (_event!.status == EventStatus.draft &&
                    !_event!.isUnpublishedByAdmin)
                  draftButton,
                saveButton,
              ];
              if (constraints.maxWidth < 760) {
                return Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: 150, child: deleteButton),
                    ...trailingButtons,
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(width: 150, child: deleteButton),
                  const Spacer(),
                  for (var i = 0; i < trailingButtons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    trailingButtons[i],
                  ],
                ],
              );
            },
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final dateField = AppTextField(
                    label: 'Date (locked)',
                    hint: '',
                    controller: _dateController,
                    enabled: false,
                    prefixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textGray,
                    ),
                  );
                  final venueField = VenueDropdownField(
                    controller: _venueController,
                    enabled: !_isSaving,
                    errorText: _errors['venue'],
                    onChanged: (_) => _clearError('venue'),
                  );
                  if (constraints.maxWidth < 680) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        dateField,
                        const SizedBox(height: 16),
                        venueField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: dateField),
                      const SizedBox(width: 16),
                      Expanded(child: venueField),
                    ],
                  );
                },
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
          title: 'Define Ticket Tiers & Prices',
          headerTrailing: TextButton.icon(
            onPressed: _addTier,
            icon: const Icon(
              Icons.add,
              size: 16,
              color: AppColors.primaryPurple,
            ),
            label: const Text(
              'Add New Tier',
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tierField = TierNameDropdown(
                      controller: tier.nameController,
                      errorText: _errors['tier$index.name'],
                      onChanged: (_) => _clearError('tier$index.name'),
                    );
                    final priceField = AppTextField(
                      label: 'Price (\u20B1)',
                      hint: '0',
                      controller: tier.priceController,
                      keyboardType: TextInputType.number,
                      errorText: _errors['tier$index.price'],
                      onChanged: (_) => _clearError('tier$index.price'),
                    );
                    final quantityField = AppTextField(
                      label: 'Quantity',
                      hint: '0',
                      controller: tier.quantityController,
                      keyboardType: TextInputType.number,
                      errorText: _errors['tier$index.quantity'],
                      onChanged: (_) => _clearError('tier$index.quantity'),
                    );
                    final removeButton = IconButton(
                      onPressed: _tiers.length > 1
                          ? () => _removeTier(index)
                          : null,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.dangerRed,
                      ),
                    );
                    if (constraints.maxWidth < 680) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          tierField,
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: priceField),
                              const SizedBox(width: 12),
                              Expanded(child: quantityField),
                              removeButton,
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(flex: 3, child: tierField),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: priceField),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: quantityField),
                        const SizedBox(width: 8),
                        removeButton,
                      ],
                    );
                  },
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
                  child: const Icon(
                    Icons.image,
                    size: 48,
                    color: Colors.white70,
                  ),
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
                            'Banner image upload is not connected yet.',
                          ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_event?.isUnpublishedByAdmin ?? false) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unpublished by an admin',
                        style: TextStyle(
                          color: AppColors.dangerRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if ((_event!.unpublishReason ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _event!.unpublishReason!,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_event!.complianceDeadline != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Upload valid documents by '
                          '${_formatDeadline(_event!.complianceDeadline!)} '
                          'or the event will be canceled.',
                          style: const TextStyle(
                            color: AppColors.dangerRed,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                (_event?.supportingDocumentUrls.isEmpty ?? true)
                    ? 'No supporting documents uploaded yet.'
                    : '${_event!.supportingDocumentUrls.length} document'
                          '${_event!.supportingDocumentUrls.length == 1 ? '' : 's'} on file.',
                style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
              OutlineButtonWidget(
                label: _isUploadingDocs ? 'Uploading...' : 'Upload Documents',
                height: 48,
                onPressed: _isUploadingDocs ? null : _uploadDocuments,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final titleWidget = Text(
                title,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryPurple,
                ),
              );
              if (headerTrailing == null) return titleWidget;
              if (constraints.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleWidget,
                    Align(
                      alignment: Alignment.centerRight,
                      child: headerTrailing,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [titleWidget, headerTrailing],
              );
            },
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
