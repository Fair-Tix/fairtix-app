import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../../services/photon_venue_service.dart';
import '../../theme/fairtix_palette.dart';

// Theme-aware pieces so these fields stay readable in dark mode.
TextStyle _labelStyle(FairTixPalette p) =>
    AppTextStyles.label.copyWith(color: p.textPrimary);
TextStyle _bodyStyle(FairTixPalette p) =>
    AppTextStyles.body.copyWith(color: p.textPrimary);
TextStyle _hintStyle(FairTixPalette p) =>
    AppTextStyles.bodyGray.copyWith(color: p.textSecondary);

OutlineInputBorder _border(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(10),
  borderSide: BorderSide(color: color),
);

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
    final p = FairTixPalette.of(context);
    return _OrganizerAutocompleteField(
      label: 'Venue',
      hint: 'Search or enter a venue',
      controller: controller,
      enabled: enabled,
      errorText: errorText,
      onChanged: onChanged,
      prefixIcon: Icon(
        Icons.location_on_outlined,
        size: 18,
        color: p.textSecondary,
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
    final p = FairTixPalette.of(context);
    final currentValue = controller.text.trim();
    final options = [
      ..._tierNames,
      if (currentValue.isNotEmpty && !_tierNames.contains(currentValue))
        currentValue,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tier Name', style: _labelStyle(p)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: currentValue.isEmpty ? null : currentValue,
          isExpanded: true,
          dropdownColor: p.surface,
          style: _bodyStyle(p),
          iconEnabledColor: p.textSecondary,
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(option, style: _bodyStyle(p)),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            controller.text = value;
            onChanged?.call(value);
          },
          decoration: InputDecoration(
            hintText: 'Select a tier',
            hintStyle: _hintStyle(p),
            errorText: errorText,
            filled: true,
            fillColor: p.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: _border(p.border),
            enabledBorder: _border(p.border),
            focusedBorder: _border(p.accentLabel),
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
    final p = FairTixPalette.of(context);

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
            color: p.surface,
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
                      title: Text(option, style: _bodyStyle(p)),
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
              Text(widget.label, style: _labelStyle(p)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              style: _bodyStyle(p),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: _hintStyle(p),
                errorText: widget.errorText ?? _lookupError,
                prefixIcon: widget.prefixIcon,
                suffixIcon: Icon(Icons.arrow_drop_down, color: p.textSecondary),
                errorBorder: _border(AppColors.dangerRed),
                focusedErrorBorder: _border(AppColors.dangerRed),
                filled: true,
                fillColor: widget.enabled ? p.surface : p.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: _border(p.border),
                enabledBorder: _border(p.border),
                focusedBorder: _border(p.accentLabel),
              ),
            ),
          ],
        );
      },
    );
  }
}
