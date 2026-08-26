import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum TimelineStepStatus { completed, inProgress, waiting }

/// One row in the vertical status timeline on the Registration Pending
/// screen (ID Submitted / Under Review / Account Activated).
class TimelineStep extends StatelessWidget {
  const TimelineStep({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.status,
    this.showConnector = true,
  });

  final String title;
  final String statusLabel;
  final TimelineStepStatus status;
  final bool showConnector;

  Color get _dotColor {
    switch (status) {
      case TimelineStepStatus.completed:
        return AppColors.success;
      case TimelineStepStatus.inProgress:
        return AppColors.warning;
      case TimelineStepStatus.waiting:
        return AppColors.faintWhite;
    }
  }

  Widget get _dotChild {
    switch (status) {
      case TimelineStepStatus.completed:
        return const Icon(Icons.check, size: 14, color: AppColors.white);
      case TimelineStepStatus.inProgress:
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.white),
        );
      case TimelineStepStatus.waiting:
        return const SizedBox.shrink();
    }
  }

  Color get _statusColor {
    switch (status) {
      case TimelineStepStatus.completed:
        return AppColors.success;
      case TimelineStepStatus.inProgress:
        return AppColors.warning;
      case TimelineStepStatus.waiting:
        return AppColors.faintWhite;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWaiting = status == TimelineStepStatus.waiting;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isWaiting ? Colors.transparent : _dotColor,
                  border: isWaiting ? Border.all(color: AppColors.faintWhite, width: 2) : null,
                ),
                child: Center(child: _dotChild),
              ),
              if (showConnector)
                Expanded(
                  child: Container(width: 2, color: AppColors.faintWhite),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
