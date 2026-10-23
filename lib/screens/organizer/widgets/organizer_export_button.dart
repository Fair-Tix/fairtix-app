import 'package:flutter/material.dart';

import '../../../services/csv_export.dart';
import '../../../services/organizer_report_service.dart';
import '../../../services/organizer_session.dart';
import '../../../services/pdf_export.dart';
import '../app_colors.dart';
import '../organizer-subscription-plan.dart';

/// "Export" control for the organizer revenue report.
///
/// On a plan with export it opens a CSV / PDF menu. On a plan without it, it
/// shows a locked button that explains the requirement and offers to open the
/// plans screen. The server enforces the same rule
/// (`organizer_revenue_report`), so this is the friendly version of it.
class OrganizerExportButton extends StatefulWidget {
  const OrganizerExportButton({super.key});

  @override
  State<OrganizerExportButton> createState() => _OrganizerExportButtonState();
}

class _OrganizerExportButtonState extends State<OrganizerExportButton> {
  bool _isExporting = false;

  Future<void> _export({required bool pdf}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final rows = await OrganizerReportService.instance.revenueReportRows();
      final today = DateTime.now().toIso8601String().split('T').first;
      final ext = pdf ? 'pdf' : 'csv';
      final fileName = 'fairtix_my_revenue_$today.$ext';
      final saved = pdf
          ? await savePdfReport(
              fileName: fileName,
              title: 'Revenue Report',
              subtitle: OrganizerSession.instance.account?.organizationName,
              rows: rows,
              showTotals: true,
            )
          : await saveCsvReport(
              fileName: fileName,
              title: 'Revenue Report',
              subtitle: OrganizerSession.instance.account?.organizationName,
              rows: rows,
              showTotals: true,
            );
      if (!mounted) return;
      if (saved) _message('Report exported ($fileName).');
    } on OrganizerReportException catch (e) {
      if (!mounted) return;
      _message(e.message);
    } catch (e) {
      if (!mounted) return;
      _message('Could not save the report: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showUpgradePrompt() async {
    final plan = OrganizerSession.instance.account?.subscriptionPlan;
    final upgrade = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report export is not in your plan'),
        content: Text(
          plan == null
              ? 'You do not have an active plan yet. Choose a plan that includes '
                    'report export to download your revenue report as CSV or '
                    'PDF.'
              : 'Your $plan plan does not include report export. Switch to a '
                    'plan that includes it to download your revenue report as '
                    'CSV or PDF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
    if (!mounted || upgrade != true) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrganizerSubscriptionPlanScreen()),
    );
    // The plan may have changed while the plans screen was open.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!OrganizerReportService.instance.canExport) {
      return TextButton.icon(
        onPressed: _showUpgradePrompt,
        icon: const Icon(Icons.lock_outline, size: 18, color: AppColors.textGray),
        label: const Text('Export', style: TextStyle(color: AppColors.textGray)),
      );
    }

    return PopupMenuButton<bool>(
      enabled: !_isExporting,
      tooltip: 'Export the revenue report',
      onSelected: (pdf) => _export(pdf: pdf),
      itemBuilder: (context) => const [
        PopupMenuItem(value: false, child: Text('Export as CSV')),
        PopupMenuItem(value: true, child: Text('Export as PDF')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 18,
              color: _isExporting ? AppColors.textGray : AppColors.primaryPurple,
            ),
            const SizedBox(width: 6),
            Text(
              _isExporting ? 'Exporting...' : 'Export',
              style: TextStyle(
                color: _isExporting ? AppColors.textGray : AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: _isExporting ? AppColors.textGray : AppColors.primaryPurple,
            ),
          ],
        ),
      ),
    );
  }
}
