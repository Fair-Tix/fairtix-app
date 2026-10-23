import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/organizer_event.dart';
import '../../services/access_control.dart';
import '../../services/event_repository.dart';
import '../../services/scanner_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-scaffold.dart';

/// Scanner Session (Mahilum design): pick an event, generate a session link
/// and 4-digit PIN for entry staff, and manage the active sessions.
///
/// Generating a session calls `generate_scanner_session`, which revokes any
/// earlier live session for the same event, so a session is only created when
/// the organizer presses "Generate Session Link". Entry staff open the Staff
/// PIN screen and type the PIN (see lib/screens/staff/).
class OrganizerScannerSessionScreen extends StatefulWidget {
  final String eventId;

  const OrganizerScannerSessionScreen({super.key, required this.eventId});

  @override
  State<OrganizerScannerSessionScreen> createState() =>
      _OrganizerScannerSessionScreenState();
}

class _SessionEntry {
  _SessionEntry({
    required this.session,
    required this.eventName,
    required this.createdAt,
  });

  final ScannerSession session;
  final String eventName;
  final DateTime createdAt;
}

class _OrganizerScannerSessionScreenState
    extends State<OrganizerScannerSessionScreen> {
  List<OrganizerEvent> _events = [];
  String? _selectedEventId;

  bool _generating = false;
  String? _errorMessage;

  /// Sessions generated from this screen, newest first. The newest one is the
  /// one whose link and PIN are shown.
  final List<_SessionEntry> _sessions = [];

  /// Latest scans for the newest session, polled so the organizer can watch
  /// entries (and rejections) come in live.
  List<ScanActivity> _activity = [];
  Timer? _activityTimer;

  _SessionEntry? get _current => _sessions.isEmpty ? null : _sessions.first;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    super.dispose();
  }

  /// Scanner sessions need admin approval and a current subscription (the
  /// database refuses otherwise). Check first so a locked organizer gets the
  /// reason up front.
  Future<void> _init() async {
    final allowed = await ensureOrganizerAccess(
      context,
      OrganizerRequirement.subscription,
    );
    if (!mounted) return;
    if (!allowed) {
      Navigator.of(context).maybePop();
      return;
    }
    if (EventRepository.instance.events.isEmpty) {
      try {
        await EventRepository.instance.refresh();
      } on EventRepositoryException {
        // The dropdown just stays empty; My Events shows the retry flow.
      }
    }
    if (!mounted) return;
    _loadEvents();
  }

  void _loadEvents() {
    final all = EventRepository.instance.events;
    final live = all.where((e) => e.status == EventStatus.published).toList();
    setState(() {
      _events = live;
      final wanted = live.any((e) => e.id == widget.eventId)
          ? widget.eventId
          : (live.isEmpty ? null : live.first.id);
      _selectedEventId = wanted;
    });
  }

  void _startActivityPolling() {
    _activityTimer?.cancel();
    _refreshActivity();
    _activityTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshActivity(),
    );
  }

  Future<void> _refreshActivity() async {
    final current = _current;
    if (current == null) return;
    try {
      final activity = await ScannerRepository.instance.fetchActivity(
        current.session.sessionId,
      );
      if (!mounted) return;
      setState(() => _activity = activity);
    } on ScannerRepositoryException {
      // A missed poll is harmless; the next tick tries again.
    }
  }

  Future<void> _generate() async {
    final id = _selectedEventId;
    if (id == null || _generating) return;
    final event = EventRepository.instance.getById(id);

    _activityTimer?.cancel();
    setState(() {
      _generating = true;
      _errorMessage = null;
      _activity = [];
    });
    try {
      final session = await ScannerRepository.instance.createSession(id);
      if (!mounted) return;
      setState(() {
        // The server revokes the previous live session for this event.
        _sessions.removeWhere((s) => s.session.eventId == id);
        _sessions.insert(
          0,
          _SessionEntry(
            session: session,
            eventName: event?.name ?? 'Event',
            createdAt: DateTime.now(),
          ),
        );
      });
      _startActivityPolling();
    } on ScannerRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _revoke(_SessionEntry entry) async {
    final p = FairTixPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
        title: Text(
          'Revoke session?',
          style: orgText(p, size: 18, weight: FontWeight.w800),
        ),
        content: Text(
          'This immediately disables the PIN for all entry staff on '
          '${entry.eventName}.',
          style: orgText(p, size: 14, color: p.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: orgText(p, size: 14, weight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Revoke',
              style: orgText(
                p,
                size: 14,
                weight: FontWeight.w700,
                color: p.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ScannerRepository.instance.endSession(entry.session.sessionId);
    } on ScannerRepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not revoke session: ${e.message}')),
      );
      return;
    }
    if (!mounted) return;
    final wasCurrent = identical(entry, _current);
    setState(() => _sessions.remove(entry));
    if (wasCurrent) {
      _activityTimer?.cancel();
      _activity = [];
      if (_current != null) _startActivityPolling();
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scanner session revoked.')));
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final wide = MediaQuery.of(context).size.width >= 1000;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _newSessionCard(p),
        if (_current != null) ...[
          const SizedBox(height: 24),
          _activityCard(p),
        ],
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _shareCard(p, wide),
        const SizedBox(height: 24),
        _activeSessionsCard(p),
      ],
    );

    return OrganizerScaffold(
      pageTitle: 'Scanner Session',
      activeItem: OrganizerNavItem.myEvents,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'My Events',
            style: orgText(p, size: 15, color: p.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Scanner Session',
            style: orgText(
              p,
              size: 36,
              weight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 24),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: right),
              ],
            )
          else ...[left, const SizedBox(height: 24), right],
        ],
      ),
    );
  }

  // --- cards ---------------------------------------------------------------

  Widget _newSessionCard(FairTixPalette p) {
    return OrganizerCard(
      radius: 28,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New session',
            style: orgText(p, size: 22, weight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          const OrganizerFieldLabel('Event'),
          const SizedBox(height: 8),
          _eventDropdown(p),
          const SizedBox(height: 16),
          Text(
            'Sessions expire automatically when the event ends. You can '
            'revoke one at any time.',
            style: orgText(p, size: 14, color: p.textSecondary, height: 1.5),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: orgText(p, size: 13, color: p.danger, height: 1.4),
            ),
          ],
          const SizedBox(height: 22),
          OrganizerPrimaryButton(
            label: 'Generate Session Link',
            loading: _generating,
            onPressed: _selectedEventId == null ? null : _generate,
            height: 52,
          ),
        ],
      ),
    );
  }

  Widget _eventDropdown(FairTixPalette p) {
    final radius = BorderRadius.circular(14);

    if (_events.isEmpty) {
      return Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: radius,
          border: Border.all(color: p.border),
        ),
        child: Text(
          'No published events',
          style: orgText(p, size: 14, color: p.textSecondary),
        ),
      );
    }

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: radius,
        border: Border.all(color: p.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedEventId,
          isExpanded: true,
          dropdownColor: p.surface,
          borderRadius: radius,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: p.textPrimary),
          style: orgText(p, size: 14),
          items: [
            for (final e in _events)
              DropdownMenuItem(
                value: e.id,
                child: Text(e.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _generating
              ? null
              : (v) => setState(() => _selectedEventId = v),
        ),
      ),
    );
  }

  Widget _shareCard(FairTixPalette p, bool wide) {
    final current = _current;

    Widget content;
    if (current == null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          'Generate a session link to get a PIN you can share with your '
          'entry staff.',
          style: orgText(p, size: 14, color: p.textSecondary, height: 1.5),
        ),
      );
    } else {
      final link = '.../scan/${current.session.token}';
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrganizerFieldLabel('Session link'),
          const SizedBox(height: 8),
          Container(
            height: 54,
            padding: const EdgeInsets.only(left: 18, right: 8),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(p, size: 14),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy link',
                  onPressed: () => _copy(link, 'Link copied.'),
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: p.accentLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const OrganizerFieldLabel('4-digit PIN'),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Copy PIN',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _copy(current.session.pin, 'PIN copied.'),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: p.accentLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in current.session.pin.split(''))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 56,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Text(
                      d,
                      style: orgText(
                        p,
                        size: 28,
                        weight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Send the PIN separately from the link.',
            style: orgText(p, size: 14, color: p.textSecondary),
          ),
        ],
      );

      final qr = _QrPlaceholder(p: p);

      content = wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 24),
                qr,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 24), qr],
            );
    }

    return OrganizerCard(
      radius: 28,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Share with entry staff',
            style: orgText(p, size: 22, weight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          content,
        ],
      ),
    );
  }

  Widget _activeSessionsCard(FairTixPalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 20),
            child: Text(
              'Active sessions',
              style: orgText(p, size: 22, weight: FontWeight.w800),
            ),
          ),
          Container(
            color: p.background.withValues(alpha: p.isDark ? 0.55 : 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              children: [
                _headCell(p, 'EVENT', 3),
                _headCell(p, 'CREATED', 2),
                _headCell(p, 'EXPIRES', 3),
                const SizedBox(width: 72),
              ],
            ),
          ),
          if (_sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'No active sessions yet.',
                style: orgText(p, size: 14, color: p.textSecondary),
              ),
            )
          else
            for (var i = 0; i < _sessions.length; i++)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: i == 0
                        ? BorderSide.none
                        : BorderSide(color: p.border),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 18,
                ),
                child: _sessionRow(p, _sessions[i]),
              ),
        ],
      ),
    );
  }

  Widget _headCell(FairTixPalette p, String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: orgText(
          p,
          size: 12,
          weight: FontWeight.w700,
          color: p.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _sessionRow(FairTixPalette p, _SessionEntry entry) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            entry.eventName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: orgText(p, size: 15, weight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            _formatDate(entry.createdAt),
            style: orgText(p, size: 14, color: p.textSecondary),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            _formatExpiry(entry.session.expiresAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: orgText(p, size: 14, color: p.textSecondary),
          ),
        ),
        SizedBox(
          width: 72,
          child: Align(
            alignment: Alignment.centerRight,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _revoke(entry),
                child: Text(
                  'Revoke',
                  style: orgText(
                    p,
                    size: 14,
                    weight: FontWeight.w700,
                    color: p.danger,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _activityCard(FairTixPalette p) {
    final accepted = _activity.where((a) => a.isAccepted).length;
    final rejected = _activity.length - accepted;

    return OrganizerCard(
      radius: 28,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Live activity',
            style: orgText(p, size: 22, weight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          if (_activity.isEmpty)
            Text(
              'No scans yet. Entries will appear here as attendees are '
              'scanned in.',
              style: orgText(p, size: 14, color: p.textSecondary, height: 1.5),
            )
          else ...[
            Row(
              children: [
                _countChip(p, 'Accepted', accepted, p.success, p.successSurface),
                const SizedBox(width: 10),
                _countChip(p, 'Rejected', rejected, p.danger, p.dangerSurface),
              ],
            ),
            const SizedBox(height: 12),
            for (final scan in _activity) _activityRow(p, scan),
          ],
        ],
      ),
    );
  }

  Widget _countChip(
    FairTixPalette p,
    String label,
    int count,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $count',
        style: orgText(p, size: 13, weight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _activityRow(FairTixPalette p, ScanActivity scan) {
    final color = scan.isAccepted ? p.success : p.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            scan.isAccepted
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.label,
                  style: orgText(
                    p,
                    size: 14,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (scan.tierName != null)
                  Text(
                    scan.tierName!,
                    style: orgText(p, size: 12, color: p.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            _formatTime(scan.scannedAt),
            style: orgText(p, size: 12, color: p.textSecondary),
          ),
        ],
      ),
    );
  }

  // --- helpers -------------------------------------------------------------

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${_months[l.month - 1]} ${l.day}, ${l.year}';
  }

  String _formatExpiry(DateTime dt) {
    final l = dt.toLocal();
    final hour12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final minute = l.minute.toString().padLeft(2, '0');
    final period = l.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(dt)} \u2022 $hour12:$minute $period';
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    final hour12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final minute = l.minute.toString().padLeft(2, '0');
    final second = l.second.toString().padLeft(2, '0');
    final period = l.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute:$second $period';
  }
}

/// Dashed box standing in for the link's QR code (as in the design).
class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.p});

  final FairTixPalette p;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: p.border, radius: 20),
      child: Container(
        width: 150,
        height: 150,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(
          'QR code for the link',
          textAlign: TextAlign.center,
          style: orgText(p, size: 13, color: p.textSecondary),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
