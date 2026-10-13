import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_colors.dart';

// ── Venue search (OpenStreetMap via Photon) ────────────────────────────────

/// One venue suggestion returned by the Photon geocoder
/// (https://photon.komoot.io — OpenStreetMap data, no API key).
class VenueSuggestion {
  final String label;
  const VenueSuggestion(this.label);

  @override
  String toString() => label;
}

class VenueSearchService {
  VenueSearchService._();
  static final VenueSearchService instance = VenueSearchService._();

  /// Searches Photon for [query]. Results are biased toward Cebu (the
  /// team's home market) but not restricted to it, so organizers elsewhere
  /// in the Philippines can still find their venue. Returns an empty list on
  /// any network/parse failure — the UI shows a typed-text fallback then.
  Future<List<VenueSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'limit': '6',
      'lang': 'en',
      'lat': '10.3157',
      'lon': '123.8854',
    });
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? const [];
      final seen = <String>{};
      final out = <VenueSuggestion>[];
      for (final f in features) {
        final props = (f as Map<String, dynamic>)['properties']
            as Map<String, dynamic>? ??
            const {};
        final parts = <String?>[
          props['name'] as String?,
          [props['housenumber'], props['street']]
              .whereType<String>()
              .join(' ')
              .trim(),
          (props['district'] ?? props['locality']) as String?,
          props['city'] as String?,
          props['state'] as String?,
          props['country'] as String?,
        ].where((p) => p != null && p.trim().isNotEmpty).cast<String>();
        // De-duplicate repeated parts ("Cebu City, Cebu City").
        final dedup = <String>[];
        for (final p in parts) {
          if (!dedup.contains(p)) dedup.add(p);
        }
        final label = dedup.join(', ');
        if (label.isNotEmpty && seen.add(label)) {
          out.add(VenueSuggestion(label));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

/// Venue field that behaves like a dropdown: as the organizer types it shows
/// matching OpenStreetMap places to pick from. The picked label is written
/// into [controller]. [isFromList] reports whether the current text came from
/// the list (so forms can insist on a real pick); if the search service is
/// unreachable the user can still use what they typed.
class VenueDropdownField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const VenueDropdownField({
    super.key,
    required this.controller,
    this.label = 'Venue *',
    this.errorText,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<VenueDropdownField> createState() => _VenueDropdownFieldState();
}

class _VenueDropdownFieldState extends State<VenueDropdownField> {
  final FocusNode _focusNode = FocusNode();
  int _requestId = 0;
  bool _loading = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Debounced async lookup. RawAutocomplete discards results of stale
  /// futures, and the [_requestId] check stops a slow earlier search from
  /// clobbering a newer one.
  Future<Iterable<VenueSuggestion>> _optionsFor(TextEditingValue value) async {
    final text = value.text.trim();
    final id = ++_requestId;
    if (text.length < 3) {
      if (_loading && mounted) setState(() => _loading = false);
      return const [];
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (id != _requestId) return const [];
    if (mounted) setState(() => _loading = true);
    final results = await VenueSearchService.instance.search(text);
    if (id != _requestId) return const [];
    if (mounted) setState(() => _loading = false);
    // Offline / no match: let them keep what they typed.
    return results.isEmpty ? [VenueSuggestion(text)] : results;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        RawAutocomplete<VenueSuggestion>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          displayStringForOption: (o) => o.label,
          optionsBuilder: _optionsFor,
          onSelected: (o) => widget.onChanged?.call(o.label),
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Search a venue (e.g. Waterfront Cebu City Hotel)',
                hintStyle: AppTextStyles.bodyGray,
                errorText: widget.errorText,
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.textGray,
                ),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.arrow_drop_down,
                        color: AppColors.textGray),
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
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.dangerRed),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.dangerRed),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 260,
                    maxWidth: 520,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final option = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, size: 18),
                        title: Text(
                          option.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Ticket tier name dropdown ──────────────────────────────────────────────

const List<String> kTierPresets = [
  'General Admission',
  'VIP',
  'VIP Standing',
  'Premium',
  'Early Bird',
  'Student',
  'Lower Box',
  'Upper Box',
  'Balcony',
  'Gold',
  'Silver',
  'Bronze',
];

const String _kOtherTier = 'Other (type your own)';

/// Dropdown for a ticket tier's name, writing the chosen value into
/// [controller] so existing create/edit code that reads
/// `nameController.text` keeps working unchanged. Picking "Other" reveals a
/// text box for a custom tier name; existing tiers whose name isn't a
/// preset open in that "Other" mode automatically.
class TierNameDropdown extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const TierNameDropdown({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
  });

  @override
  State<TierNameDropdown> createState() => _TierNameDropdownState();
}

class _TierNameDropdownState extends State<TierNameDropdown> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    final current = widget.controller.text.trim();
    if (current.isEmpty) {
      _selected = null;
    } else if (kTierPresets.contains(current)) {
      _selected = current;
    } else {
      _selected = _kOtherTier;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tier Name', style: AppTextStyles.label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selected,
          isExpanded: true,
          hint: Text('Select a tier', style: AppTextStyles.bodyGray),
          items: [
            for (final preset in [...kTierPresets, _kOtherTier])
              DropdownMenuItem(
                value: preset,
                child: Text(preset, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _selected = value;
              if (value == null) {
                widget.controller.text = '';
              } else if (value == _kOtherTier) {
                if (kTierPresets.contains(widget.controller.text.trim())) {
                  widget.controller.text = '';
                }
              } else {
                widget.controller.text = value;
              }
            });
            widget.onChanged?.call(widget.controller.text);
          },
          decoration: InputDecoration(
            errorText: widget.errorText,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.dangerRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.dangerRed),
            ),
          ),
        ),
        if (_selected == _kOtherTier) ...[
          const SizedBox(height: 8),
          TextField(
            controller: widget.controller,
            onChanged: widget.onChanged,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Custom tier name',
              hintStyle: AppTextStyles.bodyGray,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
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
      ],
    );
  }
}

/// Small helper for a red warning line under non-TextField widgets
/// (banner / supporting documents cards).
class FieldWarning extends StatelessWidget {
  final String? message;
  const FieldWarning(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.dangerRed),
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
