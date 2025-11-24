import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class QueueActionConfig {
  final String label;
  final Color color;
  final OwnerQueueStatus nextStatus;
  final bool isOutline;

  const QueueActionConfig({
    required this.label,
    required this.color,
    required this.nextStatus,
    this.isOutline = false,
  });
}

List<QueueActionConfig> queueActionsForStatus(OwnerQueueStatus status) {
  switch (status) {
    case OwnerQueueStatus.waiting:
      return const [
        QueueActionConfig(
            label: 'Start Serving',
            color: Color(0xFF2563EB),
            nextStatus: OwnerQueueStatus.serving),
      ];
    case OwnerQueueStatus.serving:
      return const [
        QueueActionConfig(
            label: 'Mark Done',
            color: Color(0xFFFFA726),
            nextStatus: OwnerQueueStatus.done),
      ];
    case OwnerQueueStatus.done:
      return const [];
  }
  return const [];
}
