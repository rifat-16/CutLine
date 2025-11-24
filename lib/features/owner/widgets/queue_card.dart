import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/utils/cutline_theme.dart';
import 'package:cutline/features/owner/utils/queue_actions.dart';
import 'package:flutter/material.dart';

class OwnerQueueCard extends StatelessWidget {
  final OwnerQueueItem item;
  final bool showActions;
  final ValueChanged<OwnerQueueStatus>? onStatusChange;
  final VoidCallback? onTap;

  const OwnerQueueCard({
    super.key,
    required this.item,
    this.showActions = true,
    this.onStatusChange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(item.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(OwnerDecorations.radius),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: OwnerDecorations.card(
              border: Border.all(color: statusColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(OwnerDecorations.radius)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            OwnerTheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          _initials(item.customerName),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: OwnerTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.customerName,
                                style: OwnerTextStyles.label
                                    .copyWith(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${item.service} • ৳${item.price}',
                                style: OwnerTextStyles.subtitle),
                            const SizedBox(height: 6),
                            Text('Barber: ${item.barberName}',
                                style: OwnerTextStyles.subtitle
                                    .copyWith(fontSize: 13)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statusLabel(item.status),
                                style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${item.waitMinutes} min',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                          const SizedBox(height: 6),
                          Text(item.slotLabel,
                              style: OwnerTextStyles.subtitle
                                  .copyWith(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showActions)
                  _ActionRow(item: item, onStatusChange: onStatusChange),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(OwnerQueueStatus status) {
    switch (status) {
      case OwnerQueueStatus.waiting:
        return Colors.amber;
      case OwnerQueueStatus.serving:
        return OwnerTheme.primary;
      case OwnerQueueStatus.done:
        return Colors.green;
    }
    return Colors.blueGrey;
  }

  String _statusLabel(OwnerQueueStatus status) {
    switch (status) {
      case OwnerQueueStatus.waiting:
        return 'Waiting';
      case OwnerQueueStatus.serving:
        return 'Serving';
      case OwnerQueueStatus.done:
        return 'Completed';
    }
    return 'In queue';
  }

  String _initials(String input) {
    final parts =
        input.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }
}

class _ActionRow extends StatelessWidget {
  final OwnerQueueItem item;
  final ValueChanged<OwnerQueueStatus>? onStatusChange;

  const _ActionRow({required this.item, this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final actions = queueActionsForStatus(item.status);
    if (actions.isEmpty) {
      return const SizedBox(height: 16);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: actions.map((action) {
          final VoidCallback? handler = onStatusChange == null
              ? null
              : () => onStatusChange!(action.nextStatus);
          if (action.isOutline) {
            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: action.color,
                side: BorderSide(color: action.color),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: handler,
              child: Text(action.label),
            );
          }
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: handler,
            child: Text(action.label),
          );
        }).toList(),
      ),
    );
  }
}
