import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/customer_detail_sheet.dart';
import 'package:cutline/features/owner/widgets/queue_card.dart';
import 'package:flutter/material.dart';

class ManageQueueScreen extends StatefulWidget {
  const ManageQueueScreen({super.key});

  @override
  State<ManageQueueScreen> createState() => _ManageQueueScreenState();
}

class _ManageQueueScreenState extends State<ManageQueueScreen>
    with SingleTickerProviderStateMixin {
  late List<OwnerQueueItem> _queue;
  String? _barberFilter;

  @override
  void initState() {
    super.initState();
    _queue = List.of(kOwnerQueueItems);
  }

  @override
  Widget build(BuildContext context) {
    final statuses = OwnerQueueStatus.values;
    return DefaultTabController(
      length: statuses.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          title: const Text('Queue control center'),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            tabs: statuses
                .map((status) => Tab(text: _statusLabel(status)))
                .toList(),
          ),
        ),
        body: Column(
          children: [
            _QueueToolbar(
              barberFilter: _barberFilter,
              barbers: _availableBarbers,
              onBarberChanged: (value) =>
                  setState(() => _barberFilter = value == 'All' ? null : value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: statuses.map((status) {
                  final filtered = _filteredQueue(status);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No ${_statusLabel(status).toLowerCase()} customers.',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final item = filtered[index];
                      return OwnerQueueCard(
                        item: item,
                        onStatusChange: (next) => _updateStatus(item.id, next),
                        onTap: () => _openCustomerDetail(item),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OwnerQueueItem> _filteredQueue(OwnerQueueStatus status) {
    Iterable<OwnerQueueItem> filtered =
        _queue.where((item) => item.status == status);
    if (_barberFilter != null) {
      filtered = filtered.where((item) => item.barberName == _barberFilter);
    }
    final sorted = filtered.toList()
      ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
    return sorted;
  }

  List<String> get _availableBarbers {
    final barbers = _queue.map((item) => item.barberName).toSet().toList()
      ..sort();
    return ['All', ...barbers];
  }

  void _updateStatus(String id, OwnerQueueStatus status) {
    setState(() {
      _queue = _queue
          .map((item) => item.id == id ? item.copyWith(status: status) : item)
          .toList();
    });
  }

  void _openCustomerDetail(OwnerQueueItem item) {
    showCustomerDetailSheet(
      context: context,
      item: item,
      onStatusChange: (status) => _updateStatus(item.id, status),
    );
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
  }
}

class _QueueToolbar extends StatelessWidget {
  final String? barberFilter;
  final List<String> barbers;
  final ValueChanged<String?> onBarberChanged;

  const _QueueToolbar({
    required this.barberFilter,
    required this.barbers,
    required this.onBarberChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          const Text('Filter barber',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(width: 12),
          Expanded(
            child: InputDecorator(
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: barberFilter ?? 'All',
                  isExpanded: true,
                  items: barbers
                      .map((barber) => DropdownMenuItem(
                            value: barber,
                            child: Text(barber),
                          ))
                      .toList(),
                  onChanged: onBarberChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
