import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../../services/photon_venue_service.dart';

class VenueDropdownField extends StatelessWidget {
  const VenueDropdownField({
    super.key,
    required this.controller,
    required this.enabled,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _OrganizerAutocompleteField(
      label: 'Venue',
      hint: 'Search or enter a venue',
      controller: controller,
      enabled: enabled,
      errorText: errorText,
      onChanged: onChanged,
      prefixIcon: const Icon(
        Icons.location_on_outlined,
        size: 18,
        color: AppColors.textGray,
      ),
    );
  }
}

class TierNameDropdown extends StatelessWidget {
  const TierNameDropdown({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  static const _tierNames = [
    'General Admission',
    'VIP',
    'Gold',
    'Silver',
    'Bronze',
    'Balcony',
  ];

  @override
  Widget build(BuildContext context) {
    final currentValue = controller.text.trim();
    final options = [
      ..._tierNames,
      if (currentValue.isNotEmpty && !_tierNames.contains(currentValue))
        currentValue,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tier Name', style: AppTextStyles.label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: currentValue.isEmpty ? null : currentValue,
          isExpanded: true,
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) {
            if (value == null) return;
            controller.text = value;
            onChanged?.call(value);
          },
          decoration: InputDecoration(
            hintText: 'Select a tier',
            hintStyle: AppTextStyles.bodyGray,
            errorText: errorText,
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryPurple),
            ),
          ),
        ),
      ],
    );
  }
}

class FieldWarning extends StatelessWidget {
  const FieldWarning(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.dangerRed),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AppColors.dangerRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerAutocompleteField extends StatefulWidget {
  const _OrganizerAutocompleteField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.enabled,
    this.errorText,
    this.onChanged,
    this.prefixIcon,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;

  @override
  State<_OrganizerAutocompleteField> createState() =>
      _OrganizerAutocompleteFieldState();
}

class _OrganizerAutocompleteFieldState
    extends State<_OrganizerAutocompleteField> {
  late final FocusNode _focusNode;
  int _searchGeneration = 0;
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim().toLowerCase();
        final generation = ++_searchGeneration;
        if (query.length < 3) {
          if (_lookupError != null && mounted) {
            setState(() => _lookupError = null);
          }
          return const Iterable<String>.empty();
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (generation != _searchGeneration) {
          return const Iterable<String>.empty();
        }
        try {
          final venues = await PhotonVenueService.instance.search(query);
          if (!mounted || generation != _searchGeneration) {
            return const Iterable<String>.empty();
          }
          if (_lookupError != null) setState(() => _lookupError = null);
          return venues;
        } on PhotonVenueServiceException catch (e) {
          if (mounted && generation == _searchGeneration) {
            setState(() => _lookupError = e.message);
          }
          return const Iterable<String>.empty();
        }
      },
      onSelected: widget.onChanged,
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      dense: true,
                      title: Text(option, style: AppTextStyles.body),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        final hasLabel = widget.label.trim().isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasLabel) ...[
              Text(widget.label, style: AppTextStyles.label),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.bodyGray,
                errorText: widget.errorText ?? _lookupError,
                prefixIcon: widget.prefixIcon,
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.textGray,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.dangerRed),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.dangerRed),
                ),
                filled: true,
                fillColor: widget.enabled
                    ? Colors.white
                    : const Color(0xFFF3F4F6),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryPurple),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
