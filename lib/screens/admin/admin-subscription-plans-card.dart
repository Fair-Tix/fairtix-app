import 'package:flutter/material.dart';

import '../../models/subscription_plan.dart';
import '../../services/subscription_plan_service.dart';
import '../organizer/app_colors.dart';

/// Admin > Platform Settings > Subscription Plans.
///
/// Lets the admin edit, add, reorder and switch off the organizer plans in
/// `public.subscription_plans`. Saving goes through
/// [SubscriptionPlanService.savePlans] (the admin-only
/// `admin_save_subscription_plans` function), which validates again on the
/// server. The same rows drive what organizers see on the plan screen, the
/// price PayMongo charges, and the limits each plan enforces.
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          maxEventsPerMonth: _parseLimit(d.events.text, name, 'events per month'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Subscription Plans',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: Color(0xFFE9D5FF),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'The plans organizers can buy through PayMongo. Price, fee '
                  'rate and limits here are what is charged and enforced. '
                  'Leave a limit blank for unlimited.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 9),
                ),
                const SizedBox(height: 14),
                _buildBody(),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Price changes apply to new purchases. Switched-off plans '
                    'stay with current subscribers.',
                    style: TextStyle(color: AppColors.textGray, fontSize: 8),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: (_loading || _saving || _loadError != null)
                      ? null
                      : _addPlan,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Plan', style: TextStyle(fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: const BorderSide(color: AppColors.primaryPurple),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_loading || _saving || _loadError != null)
                      ? null
                      : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(105, 32),
                    minimumSize: const Size(105, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.primaryPurple,
            ),
          ),
        ),
      );
    }
    if (_loadError != null) {
      return Column(
        children: [
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.dangerRed, fontSize: 10),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }
    if (_drafts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No plans yet. Use "Add Plan" to create one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGray, fontSize: 10),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _drafts.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _planEditor(i, _drafts[i]),
        ],
      ],
    );
  }

  Widget _planEditor(int index, _PlanDraft d) {
    final title = d.name.text.trim().isEmpty ? 'New plan' : d.name.text.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: d.isActive ? const Color(0xFFFAFAFD) : const Color(0xFFF3F3F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.id == null ? '$title (not saved yet)' : title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Move up',
                onPressed: index == 0 ? null : () => _move(index, -1),
                icon: const Icon(Icons.arrow_upward, size: 16),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: index == _drafts.length - 1
                    ? null
                    : () => _move(index, 1),
                icon: const Icon(Icons.arrow_downward, size: 16),
                visualDensity: VisualDensity.compact,
              ),
              if (d.id == null)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _removeNewPlan(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: AppColors.dangerRed,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 4),
              Text(
                d.isActive ? 'Active' : 'Off',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: d.isActive
                      ? AppColors.primaryPurple
                      : AppColors.textGray,
                ),
              ),
              Switch(
                value: d.isActive,
                onChanged: (value) => setState(() => d.isActive = value),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryPurple,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _field(
                'Plan name',
                d.name,
                width: 200,
                onChanged: (_) => setState(() {}),
              ),
              _field(
                'Monthly price',
                d.fee,
                prefix: '₱ ',
                number: true,
              ),
              _field(
                'Platform fee',
                d.rate,
                suffix: ' %',
                number: true,
              ),
              _field(
                'Events / month',
                d.events,
                hint: 'Unlimited',
                whole: true,
              ),
              _field(
                'Tickets / event day',
                d.tickets,
                hint: 'Unlimited',
                whole: true,
              ),
              _field(
                'Multi-day length (days)',
                d.days,
                hint: 'Unlimited',
                whole: true,
                width: 190,
              ),
              _field('Badge', d.badge, hint: 'e.g. BEST VALUE', width: 170),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Allow CSV / PDF report export',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: d.canExport,
                onChanged: (value) => setState(() => d.canExport = value),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryPurple,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: d.benefits,
            minLines: 3,
            maxLines: 8,
            style: const TextStyle(fontSize: 10),
            decoration: _decoration(
              'Benefits shown on the plan card (one per line)',
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
    bool whole = false,
    double width = 150,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: (number || whole)
            ? TextInputType.numberWithOptions(decimal: number)
            : TextInputType.text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        decoration: _decoration(
          label,
          hint: hint,
          prefix: prefix,
          suffix: suffix,
        ),
      ),
    );
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    String? prefix,
    String? suffix,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textGray, fontSize: 10),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
      prefixText: prefix,
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
    );
  }
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
