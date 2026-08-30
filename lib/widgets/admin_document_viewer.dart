import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/organizer/app_colors.dart';
import '../services/admin_user_service.dart';

/// One document to show in [showAdminReviewDialog] — label + which
/// private Storage bucket/path it lives at. [path] is null when that
/// document hasn't been uploaded yet, which the dialog renders as
/// "Not uploaded yet" instead of trying to fetch it.
class AdminReviewDocument {
  const AdminReviewDocument({
    required this.label,
    required this.bucket,
    this.path,
  });

  final String label;
  final String bucket;
  final String? path;
}

const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};

/// Shows a dialog listing [documents], fetching a fresh signed URL for
/// each one (both `identity_docs` and `organizer_docs` are private
/// Storage buckets — see supabase/policies.sql — so there's no public URL
/// to just link to directly).
///
/// When [currentStatus] is 'pending', Approve/Reject buttons are shown;
/// [onApprove]/[onReject] should perform the actual database update.
/// Otherwise a single "Close" button is shown instead — this dialog is
/// reused to just *view* documents on already-decided accounts, not only
/// to decide on pending ones.
Future<void> showAdminReviewDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<AdminReviewDocument> documents,
  required String currentStatus,
  Future<void> Function()? onApprove,
  Future<void> Function()? onReject,
}) {
  return showDialog(
    context: context,
    builder: (context) => _AdminReviewDialog(
      title: title,
      subtitle: subtitle,
      documents: documents,
      currentStatus: currentStatus,
      onApprove: onApprove,
      onReject: onReject,
    ),
  );
}

class _AdminReviewDialog extends StatefulWidget {
  const _AdminReviewDialog({
    required this.title,
    required this.subtitle,
    required this.documents,
    required this.currentStatus,
    this.onApprove,
    this.onReject,
  });

  final String title;
  final String subtitle;
  final List<AdminReviewDocument> documents;
  final String currentStatus;
  final Future<void> Function()? onApprove;
  final Future<void> Function()? onReject;

  @override
  State<_AdminReviewDialog> createState() => _AdminReviewDialogState();
}

enum _ReviewAction { approve, reject }

class _AdminReviewDialogState extends State<_AdminReviewDialog> {
  bool _isActing = false;

  /// Shows an "Are you sure?" confirmation before actually calling
  /// [onApprove]/[onReject] — approving/rejecting someone's identity
  /// verification is a one-way decision, so this is a deliberate second
  /// step rather than a single tap.
  Future<void> _confirmAndAct(_ReviewAction kind, Future<void> Function()? action) async {
    if (action == null || _isActing) return;

    final isApprove = kind == _ReviewAction.approve;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isApprove ? 'Approve verification?' : 'Reject verification?'),
        content: Text(
          isApprove
              ? "Are you sure you want to approve this user's identity verification?"
              : "Are you sure you want to reject this user's identity verification?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: isApprove ? AppColors.successGreen : AppColors.dangerRed,
            ),
            child: Text(isApprove ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _act(action);
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isActing = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.currentStatus == 'pending';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: AppTextStyles.bodyGray),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (widget.documents.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No documents on file yet.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyGray,
                          ),
                        );
                      }
                      // Side-by-side once there's room for two tiles plus
                      // spacing without squeezing them illegibly narrow;
                      // stacked (the original behavior) on tighter/mobile
                      // widths so nothing gets cut off.
                      final isWide = constraints.maxWidth >= 420 && widget.documents.length > 1;
                      if (isWide) {
                        final tileWidth = (constraints.maxWidth - 14) / 2;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final doc in widget.documents)
                              SizedBox(width: tileWidth, child: _DocumentTile(doc: doc)),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final doc in widget.documents) ...[
                            _DocumentTile(doc: doc),
                            const SizedBox(height: 14),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isPending)
                Row(
                  children: [
                    Expanded(
                      child: OutlineButtonWidget(
                        label: _isActing ? 'Please wait...' : 'Reject',
                        borderColor: AppColors.dangerRed,
                        textColor: AppColors.dangerRed,
                        onPressed: _isActing ? null : () => _confirmAndAct(_ReviewAction.reject, widget.onReject),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: _isActing ? 'Please wait...' : 'Approve',
                        color: AppColors.successGreen,
                        onPressed: _isActing ? null : () => _confirmAndAct(_ReviewAction.approve, widget.onApprove),
                      ),
                    ),
                  ],
                )
              else
                OutlineButtonWidget(
                  label: 'Close',
                  onPressed: _isActing ? null : () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({required this.doc});
  final AdminReviewDocument doc;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  Future<String>? _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    final path = widget.doc.path;
    _signedUrlFuture = path == null
        ? null
        : AdminUserService.instance.getSignedUrl(widget.doc.bucket, path);
  }

  bool get _looksLikeImage {
    final path = widget.doc.path;
    if (path == null) return false;
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return _imageExtensions.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.doc.label, style: AppTextStyles.label),
          const SizedBox(height: 8),
          if (_signedUrlFuture == null)
            const SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Not uploaded yet.',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            FutureBuilder<String>(
              future: _signedUrlFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text(
                    'Could not load this document.',
                    style: TextStyle(color: AppColors.dangerRed, fontSize: 12.5),
                  );
                }
                final url = snapshot.data!;
                if (_looksLikeImage) {
                  return GestureDetector(
                    onTap: () => _showEnlarged(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.network(
                            url,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Could not display this image.',
                                style: TextStyle(color: AppColors.dangerRed, fontSize: 12.5),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                              child: const Icon(Icons.zoom_in, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                // Non-image (e.g. a PDF permit): there's no in-app document
                // viewer wired up, so offer a copyable signed link instead
                // of trying to render it.
                return Row(
                  children: [
                    const Icon(Icons.description_outlined, color: AppColors.primaryPurple, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Document file (not previewable in-app).',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textDark),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied — paste into your browser (valid 1 hour).'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// Opens the image full-screen with pinch/drag zoom so an admin can
  /// inspect fine detail (a signature, an expiry date, a face) that the
  /// 220px thumbnail can't show clearly.
  void _showEnlarged(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 32,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
