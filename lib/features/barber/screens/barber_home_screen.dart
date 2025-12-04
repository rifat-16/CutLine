import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_home_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'barber_notification_screen.dart';
import 'barber_profile_screen.dart';

class BarberHomeScreen extends StatefulWidget {
  const BarberHomeScreen({super.key});

  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  BarberQueueStatus? _selectedStatus = BarberQueueStatus.waiting;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider =
            BarberHomeProvider(authProvider: context.read<AuthProvider>());
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<BarberHomeProvider>();
        final queue = _filteredQueue(provider.queue);

        return Scaffold(
          appBar: _buildAppBar(context, provider),
          body: RefreshIndicator(
            onRefresh: () => provider.load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusCard(
                      "Waiting",
                      provider.waitingCount,
                      "clients",
                      Colors.orange,
                    ),
                    _buildStatusCard(
                      "Serving",
                      provider.servingCount,
                      "in chairs",
                      Colors.blue,
                    ),
                    _buildStatusCard(
                      "Completed",
                      provider.completedCount,
                      "today",
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Live queue",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildQueueTabs(),
                const SizedBox(height: 16),
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (queue.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.inbox_outlined,
                            size: 40, color: Colors.black54),
                        SizedBox(height: 10),
                        Text(
                          "No customers in this queue.",
                          style: TextStyle(fontSize: 15, color: Colors.black54),
                        ),
                      ],
                    ),
                  )
                else
                  ...queue.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _QueueCard(
                        item: item,
                        onStartServing: item.status == BarberQueueStatus.waiting
                            ? () => provider.updateStatus(
                                  item.id,
                                  BarberQueueStatus.serving,
                                )
                            : null,
                        onMarkDone: item.status != BarberQueueStatus.done
                            ? () => provider.updateStatus(
                                  item.id,
                                  BarberQueueStatus.done,
                                )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, BarberHomeProvider provider) {
    final barberName = provider.profile?.name;
    return AppBar(
      titleSpacing: 0,
      centerTitle: false,
      title: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              barberName?.isNotEmpty == true ? barberName! : 'Barber',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              "Today's queue",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const BarberNotificationScreen()),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const BarberProfileScreen()),
              );
            },
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueTabs() {
    return Row(
      children: BarberQueueStatus.values.map((status) {
        final isSelected = _selectedStatus == status;
        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = status),
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _queueTab(_statusLabel(status), isSelected),
          ),
        );
      }).toList(),
    );
  }

  List<BarberQueueItem> _filteredQueue(List<BarberQueueItem> queue) {
    final selected = _selectedStatus;
    final sorted = List.of(queue)
      ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
    if (selected == null) return sorted;
    return sorted.where((item) => item.status == selected).toList();
  }
}

Widget _buildStatusCard(String title, int count, String label, Color color) {
  return Container(
    width: 110,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white, Colors.grey.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade300, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ],
    ),
  );
}

Widget _queueTab(String title, bool isSelected) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(
      color: isSelected ? Colors.blue : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Text(
      title,
      style: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _QueueCard extends StatelessWidget {
  final BarberQueueItem item;
  final VoidCallback? onStartServing;
  final VoidCallback? onMarkDone;

  const _QueueCard({
    required this.item,
    this.onStartServing,
    this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.customerName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text("${item.waitMinutes} min",
                  style: const TextStyle(color: Colors.orange, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${item.service} • ৳${item.price}   ${item.slotLabel}",
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text("Barber: ${item.barberName}",
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.note!,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _statusLabel(item.status),
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              _buildActionButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (onStartServing != null) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onStartServing,
        child: const Text(
          "Start Serving",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (onMarkDone != null) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onMarkDone,
        child: const Text(
          "Mark Completed",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        "Completed",
        style: TextStyle(
            color: Colors.green, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

String _statusLabel(BarberQueueStatus status) {
  switch (status) {
    case BarberQueueStatus.waiting:
      return 'Waiting';
    case BarberQueueStatus.serving:
      return 'Serving';
    case BarberQueueStatus.done:
      return 'Completed';
  }
}

Color _statusColor(BarberQueueStatus status) {
  switch (status) {
    case BarberQueueStatus.waiting:
      return Colors.orange;
    case BarberQueueStatus.serving:
      return Colors.blue;
    case BarberQueueStatus.done:
      return Colors.green;
  }
}
