import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/organizer_event.dart';
import '../../services/access_control.dart';
import '../../services/event_repository.dart';
import '../../services/scanner_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_skeleton.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-scaffold.dart';

/// Scanner Session (Mahilum design): pick an event, generate a session PIN,
/// a shareable scanner link and a QR code for entry staff, and manage the
/// active sessions.
///
/// Generating a session calls `generate_scanner_session`, which revokes any
/// earlier live session for the same event, so a session is only created when
/// the organizer presses "Generate Session PIN". Entry staff either type the
/// PIN on the Staff PIN screen or open the link / scan the QR code, which
/// opens that same screen with the PIN filled in (see lib/screens/staff/).
class OrganizerScannerSessionScreen extends StatefulWidget {
  final String eventId;

  const OrganizerScannerSessionScreen({super.key, required this.eventId});

  @override
  State<OrganizerScannerSessionScreen> createState() =>
      _OrganizerScannerSessionScreenState();
}

/// Loading placeholder with the page's two-column layout (switches at 1000px
/// like the real page): the "New session" card on the left, the share card and
/// the active sessions table on the right.
class _ScannerSkeleton extends StatelessWidget {
  const _ScannerSkeleton({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    const left = _SkeletonNewSession();
    const right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkeletonShare(),
        SizedBox(height: 24),
        _SkeletonSessions(),
      ],
    );

    return FtShimmer(
      child: wide
          ? const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: left),
                SizedBox(width: 24),
                Expanded(flex: 6, child: right),
              ],
            )
          : const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, SizedBox(height: 24), right],
            ),
    );
  }
}

/// Two grey text lines (full width and 70%).
class _SkeletonTextLines extends StatelessWidget {
  const _SkeletonTextLines();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FtSkeletonBox(height: 14),
        SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.7,
          alignment: Alignment.centerLeft,
          child: FtSkeletonBox(height: 14),
        ),
      ],
    );
  }
}

class _SkeletonNewSession extends StatelessWidget {
  const _SkeletonNewSession();

  @override
  Widget build(BuildContext context) {
    return const FtSkeletonPanel(
      radius: 28,
      padding: EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FtSkeletonBox(width: 140, height: 22),
          ),
          SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: FtSkeletonBox(width: 50, height: 12),
          ),
          SizedBox(height: 8),
          FtSkeletonBox(height: 54, radius: 14),
          SizedBox(height: 16),
          _SkeletonTextLines(),
          SizedBox(height: 22),
          FtSkeletonBox(height: 52, radius: 14),
        ],
      ),
    );
  }
}

class _SkeletonShare extends StatelessWidget {
  const _SkeletonShare();

  @override
  Widget build(BuildContext context) {
    return const FtSkeletonPanel(
      radius: 28,
      padding: EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FtSkeletonBox(width: 220, height: 22),
          ),
          SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: FtSkeletonBox(width: 90, height: 12),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              FtSkeletonBox(width: 56, height: 62, radius: 14),
              SizedBox(width: 12),
              FtSkeletonBox(width: 56, height: 62, radius: 14),
              SizedBox(width: 12),
              FtSkeletonBox(width: 56, height: 62, radius: 14),
              SizedBox(width: 12),
              FtSkeletonBox(width: 56, height: 62, radius: 14),
            ],
          ),
          SizedBox(height: 14),
          _SkeletonTextLines(),
          SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: FtSkeletonBox(width: 90, height: 12),
          ),
          SizedBox(height: 8),
          FtSkeletonBox(height: 50, radius: 14),
        ],
      ),
    );
  }
}

class _SkeletonSessions extends StatelessWidget {
  const _SkeletonSessions();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    Widget row({bool top = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        decoration: BoxDecoration(
          border: top ? Border(top: BorderSide(color: p.border)) : null,
        ),
        child: const Row(
          children: [
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FtSkeletonBox(width: 120, height: 15),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FtSkeletonBox(width: 80, height: 14),
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FtSkeletonBox(width: 130, height: 14),
              ),
            ),
            SizedBox(width: 72, child: FtSkeletonBox(height: 14)),
          ],
        ),
      );
    }

    return FtSkeletonPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 26, 28, 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FtSkeletonBox(width: 150, height: 22),
            ),
          ),
          Container(
            color: p.background.withValues(alpha: p.isDark ? 0.55 : 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FtSkeletonBox(width: 44, height: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FtSkeletonBox(width: 56, height: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FtSkeletonBox(width: 52, height: 12),
                  ),
                ),
                SizedBox(width: 72),
              ],
            ),
          ),
          row(),
          row(top: true),
        ],
      ),
    );
  }
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

  /// True until the access check, the event list and the live sessions have
  /// been read once, so the cards don't flash "No published events" /
  /// "No active sessions yet." before the real data arrives.
  bool _loading = true;

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
    await _loadLiveSessions();
    if (!mounted) return;
    _loadEvents();
  }

  /// Brings back the organizer's still-live sessions from the server, so they
  /// can be seen and revoked even after leaving and reopening this page.
  Future<void> _loadLiveSessions() async {
    try {
      final live = await ScannerRepository.instance.fetchMySessions();
      if (!mounted) return;
      setState(() {
        _sessions
          ..clear()
          ..addAll([
            for (final s in live)
              _SessionEntry(
                session: s.session,
                eventName: s.eventTitle,
                createdAt: s.createdAt,
              ),
          ]);
      });
      if (_sessions.isNotEmpty) _startActivityPolling();
    } on ScannerRepositoryException {
      // Not fatal: sessions made on this visit are still listed.
    }
  }

  void _loadEvents() {
    final all = EventRepository.instance.events;
    final live = all.where((e) => e.status == EventStatus.published).toList();
    setState(() {
      _events = live;
      _loading = false;
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
          if (_loading)
            _ScannerSkeleton(wide: wide)
          else if (wide)
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
            label: 'Generate Session PIN',
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
          'Generate a session to get a PIN you can share with your '
          'entry staff.',
          style: orgText(p, size: 14, color: p.textSecondary, height: 1.5),
        ),
      );
    } else {
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            'Entry staff open FairTix, choose "Entry Staff?" on the sign-in '
            'screen, and type this PIN \u2014 or use the link or QR code below. '
            'It stops working when the event ends or when you revoke it.',
            style: orgText(p, size: 14, color: p.textSecondary, height: 1.5),
          ),
          ..._linkSection(p, current.session.pin),
        ],
      );

      content = details;
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

  /// The link entry staff open to reach the PIN screen with [pin] filled in,
  /// built from the address this web app is served from. Null when that
  /// address isn't a real http(s) one (e.g. not running on the web), so no
  /// fake link is ever shown.
  String? _scannerLink(String pin) {
    if (!kIsWeb) return null;
    final base = Uri.base;
    if (base.scheme != 'http' && base.scheme != 'https') return null;
    return '${base.origin}${base.path}#/StaffPinEntryScreen?pin=$pin';
  }

  List<Widget> _linkSection(FairTixPalette p, String pin) {
    final link = _scannerLink(pin);
    if (link == null) return const [];

    return [
      const SizedBox(height: 22),
      const OrganizerFieldLabel('Scanner link'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        decoration: BoxDecoration(
          color: p.background,
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
                style: orgText(p, size: 13, color: p.textSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: () => _copy(link, 'Scanner link copied.'),
              icon: Icon(Icons.copy_rounded, size: 16, color: p.accentLabel),
              label: Text(
                'Copy Link',
                style: orgText(
                  p,
                  size: 13,
                  weight: FontWeight.w700,
                  color: p.accentLabel,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const OrganizerFieldLabel('QR code'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: QrImageView(
          data: link,
          size: 168,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Anyone with this link or QR code can scan for this event until the '
        'session ends or is revoked. Share it only with entry staff.',
        style: orgText(p, size: 13, color: p.textSecondary, height: 1.5),
      ),
    ];
  }

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
