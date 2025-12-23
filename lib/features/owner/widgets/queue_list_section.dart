import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/queue_card.dart';
import 'package:flutter/material.dart';

class OwnerQueueListSection extends StatelessWidget {
  final List<OwnerQueueItem> queue;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterChange;
  final Future<void> Function(String id, OwnerQueueStatus status) onStatusChange;
  final VoidCallback onViewAll;
  final ValueChanged<OwnerQueueItem>? onOpenCustomer;

  const OwnerQueueListSection({
    super.key,
    required this.queue,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterChange,
    required this.onStatusChange,
    required this.onViewAll,
    this.onOpenCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live queue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View full board'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: filters
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: selectedFilter == filter,
                        onSelected: (_) => onFilterChange(filter),
                        selectedColor:
                            const Color(0xFF2563EB).withValues(alpha: 0.12),
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity:
                            const VisualDensity(horizontal: -3, vertical: -3),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selectedFilter == filter
                              ? const Color(0xFF2563EB)
                              : Colors.black54,
                        ),
                        backgroundColor: const Color(0xFFF3F4F6),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (queue.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: const [
                  Icon(Icons.task_alt_outlined, size: 32, color: Colors.green),
                  SizedBox(height: 10),
                  Text('All clear! No customers in this state.'),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: queue.length > 5 ? 5 : queue.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final item = queue[index];
                return OwnerQueueCard(
                  item: item,
                  onStatusChange: (status) => onStatusChange(item.id, status),
                  onTap: onOpenCustomer == null
                      ? null
                      : () => onOpenCustomer!(item),
                );
              },
            ),
        ],
      ),
    );
  }
}
