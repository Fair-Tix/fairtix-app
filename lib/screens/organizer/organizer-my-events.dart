import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/organizer_event.dart';
import '../../services/access_control.dart';
import '../../services/event_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_skeleton.dart';
import '../../widgets/organizer_event_widgets.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-cancel-event.dart';
import 'organizer-create-event.dart';
import 'organizer-edit-event.dart';
import 'organizer-scaffold.dart';
import 'organizer-scanner-session.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Parses an event date stored as "M/D/YYYY".
DateTime? _parseDate(String raw) {
  final parts = raw.trim().split('/');
  if (parts.length != 3) return null;
  final m = int.tryParse(parts[0]);
  final d = int.tryParse(parts[1]);
  final y = int.tryParse(parts[2]);
  if (m == null || d == null || y == null || m < 1 || m > 12) return null;
  return DateTime(y, m, d);
}

enum _Filter { all, published, draft, completed, cancelled }

/// Organizer > My Events (Mahilum design): summary cards, status filters,
/// search, and one card per event with Scan / Manage / more actions.
class OrganizerMyEventsScreen extends StatefulWidget {
  const OrganizerMyEventsScreen({super.key});

  @override
  State<OrganizerMyEventsScreen> createState() =>
      _OrganizerMyEventsScreenState();
}

class _OrganizerMyEventsScreenState extends State<OrganizerMyEventsScreen> {
  bool _isLoading = true;
  String? _loadError;
  _Filter _filter = _Filter.all;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await EventRepository.instance.refresh();
    } on EventRepositoryException catch (e) {
      _loadError = e.message;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _createEvent() async {
    if (!await ensureOrganizerAccess(
      context,
      OrganizerRequirement.subscription,
    )) {
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrganizerCreateEventScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _manage(OrganizerEvent e) async {
    if (!await ensureOrganizerAccess(
      context,
      OrganizerRequirement.subscription,
    )) {
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrganizerEditEventScreen(eventId: e.id)),
    );
  }

  void _scan(OrganizerEvent e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerScannerSessionScreen(eventId: e.id),
      ),
    );
  }

  Future<void> _cancel(OrganizerEvent e) async {
    // Approval only: the server deliberately lets an organizer whose plan
    // expired still cancel an event so their buyers get refunded
    // (see supabase/access_control.sql).
    if (!await ensureOrganizerAccess(
      context,
      OrganizerRequirement.approval,
    )) {
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerCancelEventScreen(eventId: e.id),
      ),
    );
  }

  /// Deletes a draft or canceled event after confirmation. The server
  /// enforces the same rule and decides whether the row is removed or kept
  /// (hidden) to preserve sales and refund records.
  Future<void> _delete(OrganizerEvent e) async {
    if (!await ensureOrganizerAccess(
      context,
      OrganizerRequirement.approval,
    )) {
      return;
    }
    if (!mounted) return;
    final p = FairTixPalette.of(context);
    final isDraft = e.status == EventStatus.draft;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        title: Text(
          'Delete this event?',
          style: orgText(p, size: 18, weight: FontWeight.w800),
        ),
        content: Text(
          isDraft
              ? '"${e.name}" is a draft and will be permanently deleted. '
                  'This cannot be undone.'
              : '"${e.name}" will be removed from My Events. Past ticket sales '
                  'and refund records are kept for your reports.',
          style: orgText(p, size: 14, color: p.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep',
              style: orgText(p, size: 14, weight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
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
    String message;
    try {
      await EventRepository.instance.deleteEvent(e.id);
      message = 'Event deleted.';
    } on EventRepositoryException catch (err) {
      message = err.message;
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Lets the organizer send proper documents for an event an admin
  /// unpublished. The admin reviews them and republishes.
  Future<void> _uploadDocuments(OrganizerEvent e) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
    } catch (err) {
      debugPrint('Upload Docs: file picker failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the file picker: $err')),
      );
      return;
    }
    if (result == null || result.files.isEmpty) return;
    String message;
    var uploaded = 0;
    try {
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        await EventRepository.instance.uploadEventDocument(
          eventId: e.id,
          bytes: bytes,
          fileName: f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_'),
        );
        uploaded++;
      }
      message = uploaded == 0
          ? 'Could not read the selected file(s). Please try again.'
          : 'Documents submitted. An admin will review them and republish your event.';
    } on EventRepositoryException catch (err) {
      message = err.message;
    } catch (err) {
      debugPrint('Upload Docs failed: $err');
      message = 'Could not upload the document: $err';
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- filtering -----------------------------------------------------------

  bool _matchesFilter(OrganizerEvent e, _Filter f) {
    switch (f) {
      case _Filter.all:
        return true;
      case _Filter.published:
        return e.status == EventStatus.published;
      case _Filter.draft:
        return e.status == EventStatus.draft;
      case _Filter.completed:
        return e.status == EventStatus.completed;
      case _Filter.cancelled:
        return e.status == EventStatus.cancelled;
    }
  }

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final events = EventRepository.instance.events;

    return OrganizerScaffold(
      pageTitle: 'My Events',
      activeItem: OrganizerNavItem.myEvents,
      topBarTrailing: _CreateEventButton(onTap: _createEvent),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(p),
          const SizedBox(height: 24),
          if (_isLoading)
            const _MyEventsSkeleton()
          else if (_loadError != null)
            _errorState(p, _loadError!)
          else if (events.isEmpty)
            _emptyState(p)
          else
            ..._content(p, events),
        ],
      ),
    );
  }

  Widget _header(FairTixPalette p) {
    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Events',
          style: orgText(
            p,
            size: 32,
            weight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage events, scan tickets and track sales in one place.',
          style: orgText(p, size: 15, color: p.textSecondary),
        ),
      ],
    );

    final search = SizedBox(
      width: 260,
      height: 42,
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        style: orgText(p, size: 14, height: 1.3),
        cursorColor: p.accentLabel,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search events',
          hintStyle: orgText(p, size: 14, color: p.textSecondary, height: 1.3),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: p.textSecondary),
          filled: true,
          fillColor: p.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: _fieldBorder(p.border),
          enabledBorder: _fieldBorder(p.border),
          focusedBorder: _fieldBorder(p.accentLabel),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titles,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 42, child: search),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: titles), const SizedBox(width: 16), search],
        );
      },
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

  List<Widget> _content(FairTixPalette p, List<OrganizerEvent> events) {
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final e in events)
        if (_matchesFilter(e, _filter) &&
            (query.isEmpty ||
                e.name.toLowerCase().contains(query) ||
                e.venue.toLowerCase().contains(query)))
          e,
    ];

    return [
      _statCards(p, events),
      const SizedBox(height: 24),
      _filters(p, events),
      const SizedBox(height: 16),
      if (shown.isEmpty)
        OrganizerCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Center(
            child: Text(
              'No events match your filters.',
              style: orgText(p, size: 14, color: p.textSecondary),
            ),
          ),
        )
      else
        for (final e in shown) ...[
          _EventCard(
            event: e,
            onManage: () => _manage(e),
            onScan: () => _scan(e),
            onCancel: () => _cancel(e),
            onDelete: () => _delete(e),
            onUploadDocs: () => _uploadDocuments(e),
          ),
          const SizedBox(height: 14),
        ],
    ];
  }

  Widget _statCards(FairTixPalette p, List<OrganizerEvent> events) {
    final live = events.where((e) => e.status == EventStatus.published).length;

    // The soonest live event that has not happened yet.
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    OrganizerEvent? next;
    DateTime? nextDate;
    for (final e in events) {
      if (e.status != EventStatus.published) continue;
      final d = _parseDate(e.date);
      if (d == null || d.isBefore(startOfToday)) continue;
      if (nextDate == null || d.isBefore(nextDate)) {
        next = e;
        nextDate = d;
      }
    }

    return OrganizerStatGrid(
      children: [
        _StatCard(label: 'Total events', value: '${events.length}'),
        _StatCard(label: 'Live now', value: '$live', note: 'Published'),
        _StatCard(
          label: 'Tickets sold',
          value: '${EventRepository.instance.totalTicketsSold}',
          note: 'Net of refunds',
        ),
        _StatCard(
          label: 'Next event',
          value: nextDate == null
              ? '\u2014'
              : '${_months[nextDate.month - 1]} ${nextDate.day}',
          note: next?.name ?? 'No upcoming events',
        ),
      ],
    );
  }

  Widget _filters(FairTixPalette p, List<OrganizerEvent> events) {
    int count(_Filter f) => events.where((e) => _matchesFilter(e, f)).length;

    const labels = {
      _Filter.all: 'All',
      _Filter.published: 'Published',
      _Filter.draft: 'Draft',
      _Filter.completed: 'Completed',
      _Filter.cancelled: 'Cancelled',
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final f in _Filter.values)
          if (f == _Filter.all || count(f) > 0 || f == _filter)
            _FilterChip(
              label: '${labels[f]} ${count(f)}',
              selected: f == _filter,
              onTap: () => setState(() => _filter = f),
            ),
      ],
    );
  }

  Widget _errorState(FairTixPalette p, String message) {
    return OrganizerCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: p.danger),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: orgText(p, size: 14, color: p.danger),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: OrganizerSecondaryButton(
              label: 'Retry',
              height: 44,
              onPressed: _load,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(FairTixPalette p) {
    return OrganizerCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.event_note_outlined, size: 48, color: p.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No events yet',
            style: orgText(p, size: 18, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first event and it will show up here.',
            textAlign: TextAlign.center,
            style: orgText(p, size: 14, color: p.textSecondary),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 200,
            child: OrganizerPrimaryButton(
              label: 'Create Event',
              onPressed: _createEvent,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// Loading placeholder with the same structure as the loaded page: four
/// summary tiles, the filter chips and a few event rows. The header (title +
/// search) above it is real, so it is not repeated here.
class _MyEventsSkeleton extends StatelessWidget {
  const _MyEventsSkeleton();

  @override
  Widget build(BuildContext context) {
    return FtShimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrganizerStatGrid(
            children: const [
              _SkeletonStatTile(),
              _SkeletonStatTile(),
              _SkeletonStatTile(),
              _SkeletonStatTile(),
            ],
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FtSkeletonBox(width: 62, height: 36, radius: 18),
              FtSkeletonBox(width: 108, height: 36, radius: 18),
              FtSkeletonBox(width: 84, height: 36, radius: 18),
              FtSkeletonBox(width: 112, height: 36, radius: 18),
            ],
          ),
          const SizedBox(height: 16),
          const _SkeletonEventRow(),
          const SizedBox(height: 14),
          const _SkeletonEventRow(),
          const SizedBox(height: 14),
          const _SkeletonEventRow(),
        ],
      ),
    );
  }
}

class _SkeletonStatTile extends StatelessWidget {
  const _SkeletonStatTile();

  @override
  Widget build(BuildContext context) {
    return const FtSkeletonPanel(
      radius: 20,
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FtSkeletonBox(width: 90, height: 13),
          SizedBox(height: 10),
          FtSkeletonBox(width: 64, height: 28),
          SizedBox(height: 8),
          FtSkeletonBox(width: 110, height: 13),
        ],
      ),
    );
  }
}

/// Same breakpoint (900px) and column widths as [_EventCard].
class _SkeletonEventRow extends StatelessWidget {
  const _SkeletonEventRow();

  @override
  Widget build(BuildContext context) {
    const dateBlock = FtSkeletonBox(width: 58, height: 64, radius: 14);
    const avatar = FtSkeletonBox(width: 64, height: 64, radius: 14);
    const info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FtSkeletonBox(width: 220, height: 18),
        SizedBox(height: 10),
        FtSkeletonBox(width: 150, height: 14),
      ],
    );
    const sold = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FtSkeletonBox(width: 110, height: 15),
        SizedBox(height: 10),
        FtSkeletonBox(width: 190, height: 8, radius: 4),
      ],
    );
    const actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FtSkeletonBox(width: 118, height: 38),
        SizedBox(width: 8),
        FtSkeletonBox(width: 92, height: 38),
        SizedBox(width: 8),
        FtSkeletonBox(width: 40, height: 40, radius: 10),
      ],
    );

    return FtSkeletonPanel(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 900) {
            return const Row(
              children: [
                dateBlock,
                SizedBox(width: 16),
                avatar,
                SizedBox(width: 16),
                Expanded(child: info),
                SizedBox(width: 24),
                SizedBox(width: 200, child: sold),
                SizedBox(width: 24),
                SizedBox(
                  width: 290,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ),
              ],
            );
          }
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  dateBlock,
                  SizedBox(width: 14),
                  avatar,
                  SizedBox(width: 14),
                  Expanded(child: info),
                ],
              ),
              SizedBox(height: 16),
              sold,
              SizedBox(height: 16),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _CreateEventButton extends StatelessWidget {
  const _CreateEventButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(10);

    return Material(
      color: p.primary,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Create Event',
                style: orgText(
                  p,
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerCard(
      radius: 20,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: orgText(p, size: 13, color: p.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: orgText(
              p,
              size: 28,
              weight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: orgText(p, size: 13, color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? p.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? p.primary : p.border),
          ),
          child: Text(
            label,
            style: orgText(
              p,
              size: 13,
              weight: FontWeight.w600,
              color: selected ? Colors.white : p.textPrimary,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onManage,
    required this.onScan,
    required this.onCancel,
    required this.onDelete,
    required this.onUploadDocs,
  });

  final OrganizerEvent event;
  final VoidCallback onManage;
  final VoidCallback onScan;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onUploadDocs;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final e = event;
    final bannerUrl = EventRepository.instance.publicBannerUrl(e.bannerUrl);

    final dateBlock = _DateBlock(date: _parseDate(e.date));
    final avatar = OrganizerEventAvatar(event: e, bannerUrl: bannerUrl);
    final info = _info(p);
    final actions = _actions(p);

    final card = OrganizerCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 900) {
            return Row(
              children: [
                dateBlock,
                const SizedBox(width: 16),
                avatar,
                const SizedBox(width: 16),
                Expanded(child: info),
                const SizedBox(width: 24),
                SizedBox(width: 200, child: _sold(p, 190)),
                const SizedBox(width: 24),
                SizedBox(
                  width: 290,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  dateBlock,
                  const SizedBox(width: 14),
                  avatar,
                  const SizedBox(width: 14),
                  Expanded(child: info),
                ],
              ),
              const SizedBox(height: 16),
              _sold(p, null),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        },
      ),
    );

    if (!e.isUnpublishedByAdmin) return card;
    return Tooltip(
      message: e.unpublishReason ?? 'Unpublished by an admin',
      child: card,
    );
  }

  Widget _info(FairTixPalette p) {
    final e = event;
    final d = e.complianceDeadline;
    final due = (!e.isUnpublishedByAdmin || d == null)
        ? null
        : 'Documents due ${_months[d.month - 1]} ${d.day}, ${d.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: orgText(
                p,
                size: 18,
                weight: FontWeight.w800,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),
            OrganizerStatusChip(event: e),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: p.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                e.venue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: orgText(p, size: 14, color: p.textSecondary, height: 1.3),
              ),
            ),
          ],
        ),
        if (due != null) ...[
          const SizedBox(height: 4),
          Text(
            due,
            style: orgText(
              p,
              size: 12,
              weight: FontWeight.w600,
              color: p.danger,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _sold(FairTixPalette p, double? barWidth) {
    final e = event;
    final total = e.ticketsTotal;
    final ratio = total > 0 ? e.ticketsSold / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${e.ticketsSold}',
                style: orgText(p, size: 15, weight: FontWeight.w800),
              ),
              TextSpan(
                text: ' / $total sold',
                style: orgText(p, size: 15, color: p.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        barWidth == null
            ? OrganizerProgressBar(ratio: ratio)
            : OrganizerProgressBar(ratio: ratio, width: barWidth),
      ],
    );
  }

  Widget _actions(FairTixPalette p) {
    final e = event;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (e.status == EventStatus.published) ...[
          _ScanButton(onTap: onScan),
          const SizedBox(width: 8),
        ],
        _ManageButton(onTap: onManage),
        const SizedBox(width: 8),
        _MoreMenu(
          canCancel: e.status != EventStatus.cancelled,
          canDelete: e.status == EventStatus.draft ||
              e.status == EventStatus.cancelled,
          canUploadDocs: e.isUnpublishedByAdmin,
          onCancel: onCancel,
          onDelete: onDelete,
          onUploadDocs: onUploadDocs,
        ),
      ],
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Container(
      width: 58,
      height: 64,
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: p.isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date == null ? '' : _months[date!.month - 1].toUpperCase(),
            style: orgText(
              p,
              size: 11,
              weight: FontWeight.w700,
              color: p.textSecondary,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          Text(
            date == null ? '\u2014' : '${date!.day}',
            style: orgText(p, size: 22, weight: FontWeight.w800, height: 1.15),
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(8);

    return Material(
      color: p.primary.withValues(alpha: p.isDark ? 0.16 : 0.08),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.primary.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner_rounded, size: 16, color: p.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Scan tickets',
                style: orgText(
                  p,
                  size: 13,
                  weight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageButton extends StatelessWidget {
  const _ManageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(8);

    return Material(
      color: p.primary,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Text(
            'Manage',
            style: orgText(
              p,
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.canCancel,
    required this.canDelete,
    required this.canUploadDocs,
    required this.onCancel,
    required this.onDelete,
    required this.onUploadDocs,
  });

  final bool canCancel;
  final bool canDelete;
  final bool canUploadDocs;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onUploadDocs;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return PopupMenuButton<String>(
      tooltip: 'More actions',
      offset: const Offset(0, 46),
      color: p.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.border),
      ),
      onSelected: (v) {
        if (v == 'cancel') onCancel();
        if (v == 'delete') onDelete();
        if (v == 'docs') onUploadDocs();
      },
      itemBuilder: (_) => [
        if (canUploadDocs)
          PopupMenuItem(
            value: 'docs',
            child: Row(
              children: [
                Icon(Icons.upload_file_rounded, size: 18, color: p.accentLabel),
                const SizedBox(width: 10),
                Text(
                  'Upload documents',
                  style: orgText(p, size: 14, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'cancel',
          enabled: canCancel,
          child: Row(
            children: [
              Icon(Icons.event_busy_outlined, size: 18, color: p.danger),
              const SizedBox(width: 10),
              Text(
                'Cancel event',
                style: orgText(
                  p,
                  size: 14,
                  weight: FontWeight.w600,
                  color: p.danger,
                ),
              ),
            ],
          ),
        ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: p.danger),
                const SizedBox(width: 10),
                Text(
                  'Delete event',
                  style: orgText(
                    p,
                    size: 14,
                    weight: FontWeight.w600,
                    color: p.danger,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.more_horiz_rounded, size: 20, color: p.textPrimary),
      ),
    );
  }
}
