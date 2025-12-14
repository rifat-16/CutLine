import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/manage_queue_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/queue_card.dart';
import 'package:flutter/material.dart';
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
                            final filtered =
                                _filteredQueue(provider.queue, status);
                            if (filtered.isEmpty) {
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
                                itemCount: filtered.length,
                                itemBuilder: (_, index) {
                                  final item = filtered[index];
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

  List<OwnerQueueItem> _filteredQueue(
      List<OwnerQueueItem> queue, OwnerQueueStatus status) {
    Iterable<OwnerQueueItem> filtered =
        queue.where((item) => item.status == status);
    if (_barberFilter != null) {
      filtered = filtered.where((item) => item.barberName == _barberFilter);
    }
    final sorted = filtered.toList()
      ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
    return sorted;
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
