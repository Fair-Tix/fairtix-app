import 'package:flutter/material.dart';

import '../../models/subscription_plan.dart';
import '../../services/subscription_plan_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';

/// Admin > Platform Settings > Subscription Plans.
///
/// Lets the admin edit, add, reorder and switch off the organizer plans in
/// `public.subscription_plans`. Saving goes through
/// [SubscriptionPlanService.savePlans] (the admin-only
/// `admin_save_subscription_plans` function), which validates again on the
/// server. The same rows drive what organizers see on the plan screen, the
/// price PayMongo charges, and the limits each plan enforces.
///
/// The plans are laid out side by side like the organizer's "Choose your
/// plan" screen (3 / 2 / 1 columns by width), each card being the editor for
/// one plan, with a dashed "Add plan" tile at the end.
///
/// A plan is never deleted: switching it off hides it from organizers while
/// current subscribers keep it. Plans added here but not saved yet can be
/// removed outright.
class AdminSubscriptionPlansCard extends StatefulWidget {
  const AdminSubscriptionPlansCard({super.key});

  @override
  State<AdminSubscriptionPlansCard> createState() =>
      _AdminSubscriptionPlansCardState();
}

class _AdminSubscriptionPlansCardState
    extends State<AdminSubscriptionPlansCard> {
  final List<_PlanDraft> _drafts = [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final plans = await SubscriptionPlanService.instance.fetchPlans(
        activeOnly: false,
      );
      if (!mounted) return;
      for (final draft in _drafts) {
        draft.dispose();
      }
      _drafts
        ..clear()
        ..addAll([for (final plan in plans) _PlanDraft.fromPlan(plan)]);
      setState(() => _loading = false);
    } on SubscriptionPlanException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load the plans. Please try again.';
        _loading = false;
      });
    }
  }

  void _addPlan() {
    setState(() => _drafts.add(_PlanDraft()..rate.text = '8'));
  }

  void _removeNewPlan(int index) {
    setState(() => _drafts.removeAt(index).dispose());
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _drafts.length) return;
    setState(() {
      final draft = _drafts.removeAt(index);
      _drafts.insert(target, draft);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Checks every field (the server checks again) and builds the plans in
  /// their current on-screen order. Throws a [FormatException] whose message
  /// is shown to the admin.
  List<SubscriptionPlan> _buildPlans() {
    final plans = <SubscriptionPlan>[];
    final seen = <String>{};
    for (final d in _drafts) {
      final name = d.name.text.trim();
      if (name.isEmpty) {
        throw const FormatException('Every plan needs a name.');
      }
      if (!seen.add(name.toLowerCase())) {
        throw const FormatException('Each plan needs a different name.');
      }

      final fee = double.tryParse(d.fee.text.trim().replaceAll(',', ''));
      if (fee == null || fee < 20) {
        throw FormatException(
          'The monthly price of "$name" must be at least ₱20 '
          '(PayMongo minimum).',
        );
      }

      final ratePercent = double.tryParse(d.rate.text.trim());
      if (ratePercent == null || ratePercent < 0 || ratePercent > 100) {
        throw FormatException(
          'The platform fee of "$name" must be between 0% and 100%.',
        );
      }

      plans.add(
        SubscriptionPlan(
          id: d.id,
          name: name,
          monthlyFee: fee,
          feeRate: double.parse((ratePercent / 100).toStringAsFixed(4)),
          maxEventsPerMonth: _parseLimit(
            d.events.text,
            name,
            'events per month',
          ),
          maxTicketsPerDay: _parseLimit(
            d.tickets.text,
            name,
            'tickets per event day',
          ),
          maxMultiDayDays: _parseLimit(d.days.text, name, 'multi-day length'),
          canExport: d.canExport,
          benefits: [
            for (final line in d.benefits.text.split('\n'))
              if (line.trim().isNotEmpty) line.trim(),
          ],
          badge: d.badge.text.trim().isEmpty ? null : d.badge.text.trim(),
          isActive: d.isActive,
        ),
      );
    }

    if (plans.isEmpty) {
      throw const FormatException('Add at least one plan.');
    }
    if (!plans.any((p) => p.isActive)) {
      throw const FormatException(
        'At least one plan must stay active so organizers can subscribe.',
      );
    }
    return plans;
  }

  Future<void> _save() async {
    if (_saving) return;
    final List<SubscriptionPlan> plans;
    try {
      plans = _buildPlans();
    } on FormatException catch (e) {
      _showMessage(e.message);
      return;
    }

    setState(() => _saving = true);
    try {
      await SubscriptionPlanService.instance.savePlans(plans);
      if (!mounted) return;
      _showMessage('Subscription plans saved.');
      setState(() => _saving = false);
      await _load();
    } on SubscriptionPlanException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not save the plans. Please try again.');
    }
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final disabled = _loading || _saving || _loadError != null;
    final showSummary = !_loading && _loadError == null;
    final activeCount = _drafts.where((d) => d.isActive).length;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: FairTixPalette.buttonGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Subscription Plans',
                    style: orgText(p, size: 16, weight: FontWeight.w700),
                  ),
                ),
                if (showSummary)
                  _Pill(
                    label:
                        '${_drafts.length} ${_drafts.length == 1 ? 'plan' : 'plans'}'
                        ' \u00B7 $activeCount active',
                    color: p.accentLabel,
                    background: p.primary.withValues(
                      alpha: p.isDark ? 0.22 : 0.10,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'The plans organizers can buy through PayMongo. Price, fee '
                  'rate and limits here are what is charged and enforced. '
                  'Leave a limit blank for unlimited.',
                  style: orgText(
                    p,
                    size: 13,
                    color: p.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _buildBody(),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Price changes apply to new purchases. Switched-off plans '
                    'stay with current subscribers.',
                    style: orgText(
                      p,
                      size: 12,
                      color: p.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
                AdminHeaderButton(
                  label: _saving ? 'Saving...' : 'Save Changes',
                  filled: true,
                  onPressed: disabled ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final p = FairTixPalette.of(context);
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: p.accentLabel,
            ),
          ),
        ),
      );
    }
    if (_loadError != null) {
      return AdminErrorBox(message: _loadError!, onRetry: _load);
    }

    return LayoutBuilder(
      builder: (context, box) {
        const gap = 20.0;
        final columns = box.maxWidth >= 1080
            ? 3
            : (box.maxWidth >= 640 ? 2 : 1);

        // The plan cards followed by the "Add plan" tile, laid out in rows
        // whose cards all share the height of the tallest one.
        final items = <Widget>[
          for (var i = 0; i < _drafts.length; i++) _planCard(i, _drafts[i]),
          _addTile(),
        ];

        final rows = <Widget>[];
        for (var start = 0; start < items.length; start += columns) {
          final end = start + columns < items.length
              ? start + columns
              : items.length;
          final slice = items.sublist(start, end);
          if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(
                      child: j < slice.length ? slice[j] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }

  /// The dashed "+ Add plan" tile that ends the grid.
  Widget _addTile() {
    final p = FairTixPalette.of(context);
    final enabled = !_saving;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _addPlan : null,
        child: CustomPaint(
          painter: _DashedRRectPainter(color: p.border, radius: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 180),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.primary.withValues(
                          alpha: p.isDark ? 0.22 : 0.10,
                        ),
                      ),
                      child: Icon(Icons.add_rounded, color: p.accentLabel),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add plan',
                      style: orgText(p, size: 15, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a new subscription tier',
                      textAlign: TextAlign.center,
                      style: orgText(p, size: 12, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _planCard(int index, _PlanDraft d) {
    final p = FairTixPalette.of(context);
    final first = index == 0;
    final last = index == _drafts.length - 1;
    final isNew = d.id == null;

    Widget iconButton({
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
      Color? color,
    }) {
      final base = color ?? p.textSecondary;
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18,
          color: onPressed == null ? base.withValues(alpha: 0.4) : base,
        ),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: d.isActive ? p.progressTrack : p.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNew ? p.accentLabel : p.border,
          width: isNew ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status + reorder + on/off.
          Row(
            children: [
              _Pill(
                label: d.isActive ? 'Active' : 'Off',
                color: d.isActive ? p.success : p.textSecondary,
                background: d.isActive
                    ? p.successSurface
                    : p.textSecondary.withValues(alpha: 0.14),
              ),
              if (isNew) ...[
                const SizedBox(width: 6),
                _Pill(
                  label: 'Not saved yet',
                  color: p.accentLabel,
                  background: p.primary.withValues(
                    alpha: p.isDark ? 0.22 : 0.10,
                  ),
                ),
              ],
              const Spacer(),
              iconButton(
                tooltip: 'Move left',
                icon: Icons.arrow_back_rounded,
                onPressed: first ? null : () => _move(index, -1),
              ),
              iconButton(
                tooltip: 'Move right',
                icon: Icons.arrow_forward_rounded,
                onPressed: last ? null : () => _move(index, 1),
              ),
              if (isNew)
                iconButton(
                  tooltip: 'Remove',
                  icon: Icons.delete_outline_rounded,
                  color: p.danger,
                  onPressed: () => _removeNewPlan(index),
                ),
              Switch(
                value: d.isActive,
                onChanged: (value) => setState(() => d.isActive = value),
                activeThumbColor: Colors.white,
                activeTrackColor: p.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: d.isActive ? 1 : 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field('Plan name', d.name, size: 16, weight: FontWeight.w800),
                const SizedBox(height: 12),
                _field('Badge (optional)', d.badge, hint: 'e.g. BEST VALUE'),
                const SizedBox(height: 18),
                _sectionLabel('PRICING'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _field(
                        'Monthly price',
                        d.fee,
                        prefix: '₱ ',
                        suffix: ' /mo',
                        number: true,
                        size: 18,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _field(
                        'Platform fee',
                        d.rate,
                        suffix: ' %',
                        number: true,
                        size: 18,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionLabel('LIMITS', hint: 'Blank = unlimited'),
                _limitRow('Events / month', d.events),
                _limitRow('Tickets / event day', d.tickets),
                _limitRow('Multi-day length (days)', d.days),
                const SizedBox(height: 10),
                Divider(height: 1, color: p.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CSV / PDF report export',
                          style: orgText(
                            p,
                            size: 13.5,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Switch(
                        value: d.canExport,
                        onChanged: (value) =>
                            setState(() => d.canExport = value),
                        activeThumbColor: Colors.white,
                        activeTrackColor: p.primary,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: p.border),
                const SizedBox(height: 14),
                TextField(
                  controller: d.benefits,
                  minLines: 4,
                  maxLines: 8,
                  cursorColor: p.accentLabel,
                  style: orgText(p, size: 13, height: 1.4),
                  decoration: _decoration(
                    'Benefits shown on the plan card (one per line)',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {String? hint}) {
    final p = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text,
            style: orgText(
              p,
              size: 11,
              weight: FontWeight.w700,
              color: p.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          if (hint != null) ...[
            const Spacer(),
            Text(hint, style: orgText(p, size: 11, color: p.textSecondary)),
          ],
        ],
      ),
    );
  }

  /// Label on the left, a small right-aligned number box on the right.
  Widget _limitRow(String label, TextEditingController controller) {
    final p = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: orgText(p, size: 13.5, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              cursorColor: p.accentLabel,
              style: orgText(p, size: 14, weight: FontWeight.w600),
              decoration: _decoration(null, hint: 'Unlimited'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    String? prefix,
    String? suffix,
    bool number = false,
    double size = 14,
    FontWeight weight = FontWeight.w600,
  }) {
    final p = FairTixPalette.of(context);
    return TextField(
      controller: controller,
      cursorColor: p.accentLabel,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: orgText(p, size: size, weight: weight),
      decoration: _decoration(
        label,
        hint: hint,
        prefix: prefix,
        suffix: suffix,
      ),
    );
  }

  InputDecoration _decoration(
    String? label, {
    String? hint,
    String? prefix,
    String? suffix,
  }) {
    final p = FairTixPalette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: orgText(p, size: 13, color: p.textSecondary),
      hintText: hint,
      hintStyle: orgText(p, size: 13, color: p.textSecondary),
      prefixText: prefix,
      prefixStyle: orgText(p, size: 14, color: p.textSecondary),
      suffixText: suffix,
      suffixStyle: orgText(p, size: 13, color: p.textSecondary),
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(p.accentLabel),
    );
  }
}

/// Small rounded status chip.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: orgText(
          p,
          size: 11,
          weight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle outline for the "Add plan" tile.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

/// Blank means unlimited; anything else must be a positive whole number.
int? _parseLimit(String text, String planName, String what) {
  final trimmed = text.trim().replaceAll(',', '');
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value <= 0) {
    throw FormatException(
      'The $what limit of "$planName" must be a positive whole number '
      '(leave it blank for unlimited).',
    );
  }
  return value;
}

/// The editable text of one plan row.
class _PlanDraft {
  /// Null for a plan the admin added but has not saved yet.
  final String? id;
  final TextEditingController name = TextEditingController();
  final TextEditingController fee = TextEditingController();
  final TextEditingController rate = TextEditingController();
  final TextEditingController events = TextEditingController();
  final TextEditingController tickets = TextEditingController();
  final TextEditingController days = TextEditingController();
  final TextEditingController badge = TextEditingController();
  final TextEditingController benefits = TextEditingController();
  bool canExport;
  bool isActive;

  _PlanDraft({this.id, this.canExport = false, this.isActive = true});

  factory _PlanDraft.fromPlan(SubscriptionPlan plan) {
    final draft = _PlanDraft(
      id: plan.id,
      canExport: plan.canExport,
      isActive: plan.isActive,
    );
    draft.name.text = plan.name;
    draft.fee.text = _trimNumber(plan.monthlyFee);
    draft.rate.text = _trimNumber(plan.feeRate * 100);
    draft.events.text = plan.maxEventsPerMonth?.toString() ?? '';
    draft.tickets.text = plan.maxTicketsPerDay?.toString() ?? '';
    draft.days.text = plan.maxMultiDayDays?.toString() ?? '';
    draft.badge.text = plan.badge ?? '';
    draft.benefits.text = plan.benefits.join('\n');
    return draft;
  }

  void dispose() {
    name.dispose();
    fee.dispose();
    rate.dispose();
    events.dispose();
    tickets.dispose();
    days.dispose();
    badge.dispose();
    benefits.dispose();
  }
}

/// 299.0 -> "299", 8.5 -> "8.5", 9.000000000000002 -> "9".
String _trimNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
