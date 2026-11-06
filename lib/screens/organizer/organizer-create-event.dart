import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/fairtix_palette.dart';
import '../../models/organizer_event.dart';
import '../../models/showtime.dart';
import '../../services/access_control.dart';
import '../../services/event_repository.dart';
import '../../widgets/organizer_ui.dart';
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

/// One showing of a per-day multi-day event: a date plus a start time.
class _Showing {
  final DateTime date;
  final TimeOfDay time;
  const _Showing(this.date, this.time);
}

/// One option of the segmented selector used for the event duration and the
/// multi-day ticket type.
class _SegOption<T> {
  final String label;
  final IconData? icon;
  final T value;
  const _SegOption(this.label, this.value, {this.icon});
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

  // Multi-Day only. false = a separate ticket per day (cinema-style showings
  // of the same show); true = ONE pass valid on every day (convention-style).
  // Always false for Single-Day. Sent as `ticket_scope` by createEvent.
  bool _fullRunPass = false;

  // Optional start time for Single-Day events and One-pass events.
  TimeOfDay? _startTime;

  // Per-day multi-day only: every date + time the show runs (e.g. Nov 28 3 PM,
  // Nov 28 7 PM, Nov 29 3 PM, Dec 3 3 PM). Dates need not be consecutive. The
  // event's start/end date are the earliest/latest listed date. Kept sorted.
  final List<_Showing> _showings = [];

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
  void initState() {
    super.initState();
    // Backstop for any entry point other than the dashboard button: creating
    // an event needs admin approval and a current subscription. The server
    // enforces the same rule; this explains it up front.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final allowed = await ensureOrganizerAccess(
        context,
        OrganizerRequirement.subscription,
      );
      if (!allowed && mounted) Navigator.of(context).maybePop();
    });
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

  /// Number of days in the chosen multi-day run (inclusive), or null until a
  /// valid start and end date are picked.
  int? get _dayCount {
    if (_perDayMode) {
      final n = _distinctDates.length;
      return n >= 2 ? n : null;
    }
    final s = _startDate;
    final e = _endDate;
    if (s == null || e == null) return null;
    final days = DateTime.utc(e.year, e.month, e.day)
            .difference(DateTime.utc(s.year, s.month, s.day))
            .inDays +
        1;
    return days >= 2 ? days : null;
  }

  /// Tickets the organizer is offering on ONE day (sum of valid tier
  /// quantities). Every tier is copied to every day by the server.
  int get _ticketsPerDay {
    var total = 0;
    for (final t in _tiers) {
      final q = int.tryParse(t.quantityController.text.trim());
      if (q != null && q > 0) total += q;
    }
    return total;
  }

  String _rangeLabel(DateTime s, DateTime e) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final start = '${m[s.month - 1]} ${s.day}';
    final end = '${m[e.month - 1]} ${e.day}, ${e.year}';
    return s.year == e.year ? '$start \u2013 $end' : '$start, ${s.year} \u2013 $end';
  }

  // ── Shared look (matches the Organizer Dashboard) ─────────────────────────

  Color _tint(FairTixPalette p) =>
      p.primary.withValues(alpha: p.isDark ? 0.28 : 0.10);

  OutlineInputBorder _outline(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );

  /// Rounded 14px field decoration in Plus Jakarta Sans, same as the
  /// Dashboard / auth screens.
  InputDecoration _dec(
    FairTixPalette p, {
    String? hint,
    String? error,
    Widget? prefix,
    Widget? suffix,
    EdgeInsetsGeometry? padding,
  }) {
    final style = orgText(p, size: 14, height: 1.3);
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: style.copyWith(color: p.textSecondary),
      errorText: error,
      errorStyle: orgText(p, size: 12, color: p.danger),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: p.surface,
      contentPadding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: _outline(p.border),
      enabledBorder: _outline(p.border),
      focusedBorder: _outline(p.accentLabel),
      errorBorder: _outline(p.danger),
      focusedErrorBorder: _outline(p.danger),
    );
  }

  /// Label + text field.
  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? errorText,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? prefix,
  }) {
    final p = FairTixPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrganizerFieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: orgText(p, size: 14, height: 1.4),
          cursorColor: p.accentLabel,
          decoration: _dec(
            p,
            hint: hint,
            error: errorText,
            prefix: prefix,
            padding: maxLines > 1
                ? const EdgeInsets.all(16)
                : null,
          ),
        ),
      ],
    );
  }

  /// Small helper line under a field or section.
  Widget _hintText(FairTixPalette p, String text) => Text(
    text,
    style: orgText(p, size: 12, color: p.textSecondary, height: 1.45),
  );

  /// Explains the multi-day day-pass model: one ticket (and QR code) per day,
  /// valid only on that day, with every tier repeated on each day.
  Widget _dayPassSummary(FairTixPalette p) {
    final days = _dayCount;
    final perDay = _ticketsPerDay;
    final lines = <String>[
      if (_fullRunPass) ...[
        if (days != null)
          '$days days (${_rangeLabel(_startDate!, _endDate!)}): ONE pass covers '
              'every day. The QR code is accepted once per day.'
        else
          'ONE pass covers every day. The QR code is accepted once per day.',
        'Quantity is the total number of passes you sell. Your plan\'s '
            'tickets-per-day limit applies to that total.',
        if (perDay > 0) 'Capacity: $perDay passes in total.',
      ] else ...[
        if (days != null)
          '$days days (${_rangeLabel(_firstDate!, _lastDate!)}): one ticket and '
              'QR code per day, valid only on that day.'
        else
          'Each day gets its own ticket and QR code, valid only on that day.',
        if (_usesShowtimes)
          'Each showtime has its own tickets, so quantities are per showtime. '
              'One ticket per account per day, across all showtimes.'
        else
          'The tiers below are repeated on every day, so quantities are per day.',
        if (_usesShowtimes && perDay > 0)
          'Capacity: $perDay tickets per showtime, '
              '${perDay * _buildShowtimes().length} in total. Your plan\'s '
              'tickets-per-day limit counts all showtimes of a day together.'
        else if (days != null && perDay > 0)
          'Capacity: $perDay tickets per day, ${perDay * days} in total.',
      ],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: p.isDark ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 18, color: p.accentLabel),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 5),
                  Text(
                    lines[i],
                    style: orgText(
                      p,
                      size: 12.5,
                      color: p.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Multi-Day sub-choice: a separate ticket per day, or ONE pass valid on
  /// every day of the run.
  Widget _multiDayModeSelector(FairTixPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OrganizerFieldLabel('Ticket Type *'),
        const SizedBox(height: 8),
        _segmented<bool>(
          options: const [
            _SegOption(
              'Ticket per day',
              false,
              icon: Icons.confirmation_number_outlined,
            ),
            _SegOption(
              'One pass for all days',
              true,
              icon: Icons.all_inclusive_rounded,
            ),
          ],
          selected: _fullRunPass,
          onChanged: (passMode) => setState(() => _fullRunPass = passMode),
        ),
      ],
    );
  }

  /// Segmented selector: soft track with a gradient pill on the selection.
  Widget _segmented<T>({
    required List<_SegOption<T>> options,
    required T selected,
    required ValueChanged<T> onChanged,
  }) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.progressTrack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isSubmitting ? null : () => onChanged(o.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: o.value == selected
                          ? FairTixPalette.buttonGradient
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: o.value == selected
                          ? [
                              BoxShadow(
                                color: p.primary.withValues(
                                  alpha: p.isDark ? 0.40 : 0.28,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (o.icon != null) ...[
                          Icon(
                            o.icon,
                            size: 17,
                            color: o.value == selected
                                ? Colors.white
                                : p.textSecondary,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            o.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: orgText(
                              p,
                              size: 14,
                              weight: FontWeight.w700,
                              height: 1.2,
                              color: o.value == selected
                                  ? Colors.white
                                  : p.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Start time / showings ────────────────────────────────────────────────────────────────
  static const List<String> _kMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _timeKey(TimeOfDay t) => clockTimeString(t.hour, t.minute);
  String _timeLabel(TimeOfDay t) => formatClockTime(_timeKey(t)) ?? _timeKey(t);
  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  String _dayShort(DateTime d) => '${_kMonths[d.month - 1]} ${d.day}';
  static const List<String> _kWeekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  String _dateLabel(DateTime d) => '${_kWeekdays[d.weekday - 1]}, ${_dayShort(d)}';

  /// Per-day multi-day (a separate ticket per day): the days come from the
  /// showings list instead of a start/end date.
  bool get _perDayMode => _span == EventSpan.multiDay && !_fullRunPass;

  /// True when this is a per-day multi-day event with at least one showing.
  bool get _usesShowtimes => _perDayMode && _showings.isNotEmpty;

  /// The distinct dates that have a showing, in order.
  List<DateTime> get _distinctDates {
    final keys = <String>{};
    final dates = <DateTime>[];
    for (final s in _showings) {
      if (keys.add(_dayKey(s.date))) dates.add(s.date);
    }
    return dates;
  }

  /// Earliest / latest event date: from the showings in per-day mode, else the
  /// start / end date pickers.
  DateTime? get _firstDate =>
      _perDayMode ? (_showings.isEmpty ? null : _showings.first.date) : _startDate;
  DateTime? get _lastDate =>
      _perDayMode ? (_showings.isEmpty ? null : _showings.last.date) : _endDate;

  /// The showings sent to the server.
  List<Showtime> _buildShowtimes() {
    if (!_usesShowtimes) return const [];
    return [
      for (final s in _showings) Showtime(date: s.date, time: _timeKey(s.time)),
    ];
  }

  /// "HH:MM" for a Single-Day / One-pass event, else null.
  String? _buildStartTime() {
    final t = _startTime;
    if (t == null) return null;
    if (_span == EventSpan.singleDay || _fullRunPass) return _timeKey(t);
    return null;
  }

  /// Asks for a date, then a time, and adds that showing (kept sorted).
  Future<void> _addShowing() async {
    final today = DateUtils.dateOnly(DateTime.now());
    var initial = _showings.isEmpty ? today : _showings.last.date;
    if (initial.isBefore(today)) initial = today;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 10, today.month, today.day),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 15, minute: 0),
    );
    if (time == null || !mounted) return;
    final day = DateUtils.dateOnly(date);
    final exists = _showings.any(
      (s) => _dayKey(s.date) == _dayKey(day) && _timeKey(s.time) == _timeKey(time),
    );
    if (exists) return;
    setState(() {
      _showings.add(_Showing(day, time));
      _showings.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return (a.time.hour * 60 + a.time.minute)
            .compareTo(b.time.hour * 60 + b.time.minute);
      });
      _errors.remove('showtimes');
    });
  }

  void _removeShowing(_Showing s) {
    setState(() {
      _showings.remove(s);
      _errors.remove('showtimes');
    });
  }

  /// Optional start time for Single-Day and One-pass events.
  Widget _startTimeField(FairTixPalette p) {
    final t = _startTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OrganizerFieldLabel('Start Time (optional)'),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isSubmitting
              ? null
              : () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: t ?? const TimeOfDay(hour: 19, minute: 0),
                  );
                  if (picked != null && mounted) {
                    setState(() => _startTime = picked);
                  }
                },
          child: InputDecorator(
            decoration: _dec(
              p,
              prefix: Icon(
                Icons.access_time_rounded,
                size: 18,
                color: p.textSecondary,
              ),
              suffix: t == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear time',
                      icon: Icon(Icons.close, size: 18, color: p.textSecondary),
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _startTime = null),
                    ),
            ),
            child: Text(
              t == null ? 'No set time' : _timeLabel(t),
              style: orgText(
                p,
                size: 14,
                height: 1.3,
                color: t == null ? p.textSecondary : p.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _hintText(
          p,
          'Shown on the event and on tickets. Resale closes 24 hours before this time.',
        ),
      ],
    );
  }

  /// Per-day multi-day only: the list of date + time showings. Each date gets
  /// its own row of time chips; dates need not be consecutive.
  Widget _showingsSection(FairTixPalette p) {
    final dates = _distinctDates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OrganizerFieldLabel('Showings *'),
        const SizedBox(height: 6),
        _hintText(
          p,
          'Add each date and time the show runs. Dates do not have to be back to '
          'back (e.g. Nov 28, 29, 30, then Dec 3, 4, 5). A date can have several '
          'times, and every showing has its own tickets. A buyer can hold one '
          'ticket per date across all its showings.',
        ),
        const SizedBox(height: 14),
        for (final date in dates)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: p.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      _dateLabel(date),
                      style: orgText(p, size: 13, weight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final s in _showings)
                          if (_dayKey(s.date) == _dayKey(date))
                            InputChip(
                              label: Text(_timeLabel(s.time)),
                              onDeleted: _isSubmitting
                                  ? null
                                  : () => _removeShowing(s),
                              labelStyle: orgText(
                                p,
                                size: 12,
                                weight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              backgroundColor: p.primary,
                              deleteIconColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: Icon(Icons.add_rounded, size: 18, color: p.accentLabel),
            label: Text(
              'Add showing',
              style: orgText(
                p,
                size: 13,
                weight: FontWeight.w700,
                color: p.accentLabel,
                height: 1.2,
              ),
            ),
            onPressed: _isSubmitting ? null : _addShowing,
            backgroundColor: _tint(p),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        if (dates.isNotEmpty) ...[
          const SizedBox(height: 10),
          _hintText(
            p,
            '${dates.length} day${dates.length == 1 ? '' : 's'}, '
            '${_showings.length} showing${_showings.length == 1 ? '' : 's'}',
          ),
        ],
        FieldWarning(_errors['showtimes']),
      ],
    );
  }

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

  /// Uploads the selected attachments for [event]. A publish must not proceed
  /// unless every required document has been uploaded successfully.
  Future<void> _uploadAttachments(OrganizerEvent event) async {
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
    final today = DateUtils.dateOnly(DateTime.now());

    if (_eventNameController.text.trim().isEmpty) {
      errors['name'] = 'Event name is required.';
    }
    if (_perDayMode) {
      // Dates come from the showings (checked below).
    } else if (_startDate == null) {
      errors['start'] = _span == EventSpan.singleDay
          ? 'Pick a date for the event.'
          : 'Pick a start date.';
    } else if (DateUtils.dateOnly(_startDate!).isBefore(today)) {
      errors['start'] = 'Event dates cannot be in the past.';
    }
    if (_span == EventSpan.multiDay && !_perDayMode) {
      if (_endDate == null) {
        errors['end'] = 'Pick an end date.';
      } else if (DateUtils.dateOnly(_endDate!).isBefore(today)) {
        errors['end'] = 'Event dates cannot be in the past.';
      } else if (_startDate != null && !_endDate!.isAfter(_startDate!)) {
        errors['end'] = 'End date must be after the start date.';
      }
    }

    if (forPublish) {
      if (_venueController.text.trim().isEmpty) {
        errors['venue'] = 'Search and pick a venue.';
      }
      if (_documents.isEmpty) {
        errors['documents'] = 'Upload at least one supporting document (venue contract, permit, etc.).';
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

    if (_perDayMode) {
      if (_distinctDates.length < 2) {
        errors['showtimes'] = 'Add showings on at least 2 different dates.';
      } else {
        final now = DateTime.now();
        final inPast = _showings.any(
          (s) => DateTime(
            s.date.year, s.date.month, s.date.day, s.time.hour, s.time.minute,
          ).isBefore(now),
        );
        if (inPast) {
          errors['showtimes'] =
              'A showing is in the past. Remove it or pick a later time.';
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
        startDate: _firstDate!,
        endDate: _span == EventSpan.multiDay ? _lastDate : null,
        fullRunPass: _span == EventSpan.multiDay && _fullRunPass,
        startTime: _buildStartTime(),
        showtimes: _buildShowtimes(),
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
        startDate: _firstDate!,
        endDate: _span == EventSpan.multiDay ? _lastDate : null,
        fullRunPass: _span == EventSpan.multiDay && _fullRunPass,
        startTime: _buildStartTime(),
        showtimes: _buildShowtimes(),
        // Keep the event unpublished until all required documents are safely
        // stored. If any upload fails, the draft remains available to retry.
        status: EventStatus.draft,
        tiers: _buildTiers(),
      );

      await _uploadAttachments(event);
      final eventWithAttachments =
          EventRepository.instance.getById(event.id) ?? event;
      await EventRepository.instance.updateEvent(
        eventWithAttachments,
        publish: true,
      );

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1000;

    return OrganizerScaffold(
      pageTitle: 'Create New Event',
      activeItem: OrganizerNavItem.dashboard,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(p, isWide),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            _errorBanner(p),
          ],
          const SizedBox(height: 24),
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
          const SizedBox(height: 28),
          if (_formError != null) ...[
            _errorBanner(p),
            const SizedBox(height: 16),
          ],
          Align(alignment: Alignment.centerRight, child: _actions()),
        ],
      ),
    );
  }

  /// Page header, same pattern as the Dashboard: title + subtitle on the left,
  /// actions on the right.
  Widget _header(FairTixPalette p, bool isWide) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create New Event',
              style: orgText(
                p,
                size: isWide ? 36 : 28,
                weight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fill in the details below, then save a draft or publish.',
              style: orgText(p, size: 15, color: p.textSecondary),
            ),
          ],
        ),
        _actions(),
      ],
    );
  }

  /// Cancel / Save as Draft / Publish Event, in the Dashboard button style.
  Widget _actions() {
    final busy = _isSubmitting;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        SizedBox(
          width: 110,
          child: Opacity(
            opacity: busy ? 0.5 : 1,
            child: OrganizerSecondaryButton(
              label: 'Cancel',
              height: 50,
              onPressed: busy ? null : () => Navigator.pop(context),
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: Opacity(
            opacity: busy ? 0.5 : 1,
            child: OrganizerSecondaryButton(
              label: 'Save as Draft',
              height: 50,
              onPressed: busy ? null : _saveDraft,
            ),
          ),
        ),
        SizedBox(
          width: 170,
          child: OrganizerPrimaryButton(
            label: 'Publish Event',
            height: 50,
            loading: busy,
            onPressed: busy ? null : _publishEvent,
          ),
        ),
      ],
    );
  }

  /// Styled form-level error.
  Widget _errorBanner(FairTixPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: p.dangerSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: p.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _formError!,
              style: orgText(
                p,
                size: 13.5,
                weight: FontWeight.w600,
                color: p.danger,
                height: 1.4,
              ),
            ),
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
    final today = DateUtils.dateOnly(DateTime.now());
    final requestedFirstDate = DateUtils.dateOnly(firstDate);
    final pickerFirstDate = requestedFirstDate.isBefore(today)
        ? today
        : requestedFirstDate;
    final initialDate = pickerFirstDate;
    final p = FairTixPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrganizerFieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          style: orgText(p, size: 14, height: 1.3),
          enabled: !_isSubmitting,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: pickerFirstDate,
              lastDate: DateTime(today.year + 10, today.month, today.day),
            );
            if (date != null) {
              onPicked(date);
              if (errorKey != null) _clearError(errorKey);
            }
          },
          decoration: _dec(
            p,
            hint: 'Select date',
            error: errorKey == null ? null : _errors[errorKey],
            prefix: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: p.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _leftColumn() {
    final p = FairTixPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: 'Basic Information',
          icon: Icons.edit_note_rounded,
          subtitle: 'Name your event and tell attendees what it is about.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                label: 'Event Name *',
                hint: 'e.g. BINI Signals World Tour',
                controller: _eventNameController,
                errorText: _errors['name'],
                onChanged: (_) => _clearError('name'),
              ),
              const SizedBox(height: 20),
              _field(
                label: 'Description',
                hint: 'Tell attendees about your event...',
                controller: _descriptionController,
                maxLines: 5,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _card(
          title: 'Date & Time',
          icon: Icons.event_outlined,
          subtitle: 'Choose how long your event runs and when it starts.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OrganizerFieldLabel('Event Duration *'),
              const SizedBox(height: 8),
              _segmented<EventSpan>(
                options: const [
                  _SegOption(
                    'Single-Day',
                    EventSpan.singleDay,
                    icon: Icons.today_outlined,
                  ),
                  _SegOption(
                    'Multi-Day',
                    EventSpan.multiDay,
                    icon: Icons.date_range_outlined,
                  ),
                ],
                selected: _span,
                onChanged: (value) => setState(() {
                  if (value == EventSpan.singleDay) {
                    _span = EventSpan.singleDay;
                    _endDate = null;
                    _fullRunPass = false;
                    _showings.clear();
                    _endDateController.clear();
                  } else {
                    _span = EventSpan.multiDay;
                  }
                }),
              ),
              if (_span == EventSpan.multiDay) ...[
                const SizedBox(height: 20),
                _multiDayModeSelector(p),
                const SizedBox(height: 14),
                _dayPassSummary(p),
              ],
              if (!_perDayMode) ...[
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          : _startTimeField(p),
                    ),
                  ],
                ),
              ],
              if (_fullRunPass) ...[
                const SizedBox(height: 20),
                _startTimeField(p),
              ],
              if (_span == EventSpan.multiDay && !_fullRunPass) ...[
                const SizedBox(height: 20),
                _showingsSection(p),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _card(
          title: 'Venue',
          icon: Icons.location_on_outlined,
          subtitle: 'Where will attendees go?',
          child: VenueDropdownField(
            controller: _venueController,
            enabled: !_isSubmitting,
            errorText: _errors['venue'],
            onChanged: (_) => _clearError('venue'),
          ),
        ),
        const SizedBox(height: 24),
        _card(
          title: 'Ticket Tiers & Prices',
          icon: Icons.confirmation_number_outlined,
          subtitle: 'Create each ticket type with its price and quantity.',
          headerTrailing: TextButton.icon(
            onPressed: _isSubmitting ? null : _addTier,
            style: TextButton.styleFrom(
              backgroundColor: _tint(p),
              foregroundColor: p.accentLabel,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.add_rounded, size: 18, color: p.accentLabel),
            label: Text(
              'Add Tier',
              style: orgText(
                p,
                size: 13,
                weight: FontWeight.w700,
                color: p.accentLabel,
                height: 1.2,
              ),
            ),
          ),
          child: Column(
            children: [
              FieldWarning(_errors['tiers']),
              for (var i = 0; i < _tiers.length; i++) _tierCard(i, p),
            ],
          ),
        ),
      ],
    );
  }

  /// One ticket tier: numbered header with a remove button, then the name,
  /// price and quantity fields (side by side when there is room).
  Widget _tierCard(int index, FairTixPalette p) {
    final tier = _tiers[index];
    final qtyLabel = _span == EventSpan.multiDay
        ? (_fullRunPass
              ? 'Total passes'
              : (_usesShowtimes ? 'Qty per showtime' : 'Qty per day'))
        : 'Quantity';

    final nameField = TierNameDropdown(
      controller: tier.nameController,
      errorText: _errors['tier$index.name'],
      onChanged: (_) => _clearError('tier$index.name'),
    );
    final priceField = _field(
      label: 'Price (\u20B1)',
      hint: '2500',
      controller: tier.priceController,
      keyboardType: TextInputType.number,
      errorText: _errors['tier$index.price'],
      onChanged: (_) => _clearError('tier$index.price'),
    );
    final qtyField = _field(
      label: qtyLabel,
      hint: '200',
      controller: tier.quantityController,
      keyboardType: TextInputType.number,
      errorText: _errors['tier$index.quantity'],
      onChanged: (_) {
        _clearError('tier$index.quantity');
        // Keep the per-day / total capacity line current.
        if (_span == EventSpan.multiDay) setState(() {});
      },
    );

    return Container(
      key: ObjectKey(tier),
      margin: EdgeInsets.only(bottom: index == _tiers.length - 1 ? 0 : 16),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tint(p),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${index + 1}',
                  style: orgText(
                    p,
                    size: 13,
                    weight: FontWeight.w800,
                    color: p.accentLabel,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tier ${index + 1}',
                  style: orgText(p, size: 15, weight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Remove tier',
                onPressed: _tiers.length > 1 && !_isSubmitting
                    ? () => _removeTier(index)
                    : null,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: _tiers.length > 1 ? p.danger : p.border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nameField,
                    const SizedBox(height: 16),
                    priceField,
                    const SizedBox(height: 16),
                    qtyField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: nameField),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: priceField),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: qtyField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _rightColumn() {
    final p = FairTixPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: 'Event Banner',
          icon: Icons.image_outlined,
          subtitle: 'The cover image shown to buyers.',
          child: _bannerBytes != null
              ? MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : _pickBanner,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          ColoredBox(
                            color: const Color(0xFF1B0F3F),
                            child: SizedBox(
                              height: 190,
                              width: double.infinity,
                              child: Image.memory(
                                _bannerBytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Change image',
                                    style: orgText(
                                      p,
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : OrganizerUploadBox(
                  title: 'Upload banner image',
                  hint: '16:9 aspect ratio recommended',
                  onTap: () {
                    if (!_isSubmitting) _pickBanner();
                  },
                ),
        ),
        const SizedBox(height: 24),
        _card(
          title: 'Supporting Documents *',
          icon: Icons.description_outlined,
          subtitle: 'Required to publish.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_documents.isEmpty)
                _hintText(
                  p,
                  'Venue contract, permit, or other proof. PDF, JPG or PNG.',
                )
              else
                for (var i = 0; i < _documents.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: p.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: p.accentLabel,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _documents[i].fileName,
                            overflow: TextOverflow.ellipsis,
                            style: orgText(
                              p,
                              size: 13,
                              weight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _isSubmitting
                              ? null
                              : () => setState(() => _documents.removeAt(i)),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: p.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 12),
              OrganizerUploadBox(
                title: _documents.isEmpty ? 'Add document' : 'Add another',
                hint: 'PDF, JPG or PNG',
                onTap: () {
                  if (!_isSubmitting) _pickDocuments();
                },
              ),
              FieldWarning(_errors['documents']),
            ],
          ),
        ),
      ],
    );
  }

  /// Section card in the Dashboard style: rounded surface, soft shadow, a
  /// tinted icon tile, bold title and a one-line subtitle.
  Widget _card({
    required String title,
    required Widget child,
    IconData? icon,
    String? subtitle,
    Widget? headerTrailing,
  }) {
    final p = FairTixPalette.of(context);
    return OrganizerCard(
      radius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleWidget = Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _tint(p),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 22, color: p.accentLabel),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: orgText(
                            p,
                            size: 18,
                            weight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: orgText(
                              p,
                              size: 13,
                              color: p.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
              if (headerTrailing == null) return titleWidget;
              if (constraints.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: headerTrailing,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Expanded(child: titleWidget), headerTrailing],
              );
            },
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
