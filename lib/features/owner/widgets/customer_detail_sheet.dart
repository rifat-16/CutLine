import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/utils/queue_actions.dart';
import 'package:flutter/material.dart';

Future<void> showCustomerDetailSheet({
  required BuildContext context,
  required OwnerQueueItem item,
  ValueChanged<OwnerQueueStatus>? onStatusChange,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _CustomerDetailBody(
      item: item,
      onStatusChange: onStatusChange,
    ),
  );
}

class _CustomerDetailBody extends StatelessWidget {
  final OwnerQueueItem item;
  final ValueChanged<OwnerQueueStatus>? onStatusChange;

  const _CustomerDetailBody({
    required this.item,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final actions = queueActionsForStatus(item.status);
    final bottom = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              item.customerName,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Text(
              '${item.service} • ৳${item.price}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            _InfoTile(
              icon: Icons.phone_rounded,
              label: 'Phone',
              value: item.customerPhone,
            ),
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.access_time,
              label: 'ETA',
              value: '${item.waitMinutes} minutes',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.chair_alt_outlined,
              label: 'Assigned barber',
              value: item.barberName,
            ),
            if (item.note?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.sticky_note_2_outlined,
                label: 'Notes',
                value: item.note!,
                multiLine: true,
              ),
            ],
            const SizedBox(height: 24),
            if (actions.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('This visit is already completed.'),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: actions.map((action) {
                  final button = action.isOutline
                      ? OutlinedButton(
                          onPressed: () => _handleAction(context, action),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: action.color,
                            side: BorderSide(color: action.color),
                            minimumSize: const Size(140, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(action.label),
                        )
                      : ElevatedButton(
                          onPressed: () => _handleAction(context, action),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: action.color,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(140, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(action.label),
                        );
                  return button;
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, QueueActionConfig action) {
    Navigator.of(context).pop();
    onStatusChange?.call(action.nextStatus);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiLine;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
