import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/manage_queue_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/queue_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ManageQueueScreen extends StatefulWidget {
  const ManageQueueScreen({super.key});

  @override
  State<ManageQueueScreen> createState() => _ManageQueueScreenState();
}

class _ManageQueueScreenState extends State<ManageQueueScreen>
    with SingleTickerProviderStateMixin {
  String? _barberFilter;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = ManageQueueProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<ManageQueueProvider>();
        const statuses = [
          OwnerQueueStatus.waiting,
          OwnerQueueStatus.serving,
          OwnerQueueStatus.done,
        ];
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
                  barbers: _availableBarbers(provider.queue),
                  onBarberChanged: (value) => setState(
                      () => _barberFilter = value == 'All' ? null : value),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          children: statuses.map((status) {
                            final entries =
                                _buildQueueEntries(provider.queue, status);
                            if (entries.isEmpty) {
                              return Center(
                                child: Text(
                                  'No ${_statusLabel(status).toLowerCase()} customers.',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              );
                            }
                            return RefreshIndicator(
                              onRefresh: () => provider.load(),
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 12, 20, 80),
                                itemCount: entries.length,
                                itemBuilder: (_, index) {
                                  final entry = entries[index];
                                  if (entry.isHeader) {
                                    return _DateHeader(label: entry.label);
                                  }
                                  final item = entry.item!;
                                  return OwnerQueueCard(
                                    item: item,
                                    onStatusChange: (next) =>
                                        provider.updateStatus(item.id, next),
                                    onTap: null,
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_QueueEntry> _buildQueueEntries(
      List<OwnerQueueItem> queue, OwnerQueueStatus status) {
    Iterable<OwnerQueueItem> filtered =
        queue.where((item) => item.status == status);
    if (_barberFilter != null) {
      filtered = filtered.where((item) => item.barberName == _barberFilter);
    }

    final sorted = filtered.toList()
      ..sort((a, b) => _compareBySchedule(a, b, status));
    if (sorted.isEmpty) return const [];

    final entries = <_QueueEntry>[];
    DateTime? lastDay;
    for (final item in sorted) {
      final scheduledAt = item.scheduledAt;
      final day = scheduledAt == null
          ? null
          : DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
      if (lastDay != day) {
        entries.add(_QueueEntry.header(_dayLabel(day)));
        lastDay = day;
      }
      entries.add(_QueueEntry.item(item));
    }
    return entries;
  }

  int _compareBySchedule(
      OwnerQueueItem a, OwnerQueueItem b, OwnerQueueStatus status) {
    final aDt = a.scheduledAt;
    final bDt = b.scheduledAt;

    // Scheduled items first; unscheduled last.
    if (aDt == null && bDt != null) return 1;
    if (aDt != null && bDt == null) return -1;

    // If both scheduled, sort by date+time.
    if (aDt != null && bDt != null) {
      final cmp =
          status == OwnerQueueStatus.done ? bDt.compareTo(aDt) : aDt.compareTo(bDt);
      if (cmp != 0) return cmp;
    }

    // Stable fallback: shorter wait first, then name.
    final waitCmp = a.waitMinutes.compareTo(b.waitMinutes);
    if (waitCmp != 0) return waitCmp;
    return a.customerName.compareTo(b.customerName);
  }

  String _dayLabel(DateTime? day) {
    if (day == null) return 'Unscheduled';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = day.difference(today).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Tomorrow';
    if (diffDays == -1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(day);
  }

  List<String> _availableBarbers(List<OwnerQueueItem> queue) {
    final barbers = queue.map((item) => item.barberName).toSet().toList()
      ..sort();
    return ['All', ...barbers];
  }

  String _statusLabel(OwnerQueueStatus status) {
    switch (status) {
      case OwnerQueueStatus.waiting:
        return 'Waiting';
      case OwnerQueueStatus.turnReady:
        return 'Turn Ready';
      case OwnerQueueStatus.arrived:
        return 'Arrived';
      case OwnerQueueStatus.serving:
        return 'Serving';
      case OwnerQueueStatus.done:
        return 'Completed';
      case OwnerQueueStatus.noShow:
        return 'No Show';
    }
  }
}

class _QueueEntry {
  final bool isHeader;
  final String label;
  final OwnerQueueItem? item;

  const _QueueEntry._({
    required this.isHeader,
    required this.label,
    required this.item,
  });

  factory _QueueEntry.header(String label) =>
      _QueueEntry._(isHeader: true, label: label, item: null);

  factory _QueueEntry.item(OwnerQueueItem item) =>
      _QueueEntry._(isHeader: false, label: '', item: item);
}

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
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
