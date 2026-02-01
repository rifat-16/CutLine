import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/work_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkHistoryScreen extends StatelessWidget {
  const WorkHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider =
            WorkHistoryProvider(authProvider: context.read<AuthProvider>());
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<WorkHistoryProvider>();
        return Scaffold(
          appBar: AppBar(
            title: const Text("Work History"),
            centerTitle: true,
            elevation: 0,
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => provider.load(),
                  child: provider.items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (provider.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Center(
                                  child: Text(
                                    provider.error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Center(
                              child: Column(
                                children: const [
                                  Icon(Icons.history,
                                      size: 48, color: Colors.black45),
                                  SizedBox(height: 8),
                                  Text(
                                    'No history yet',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Completed jobs will appear here.',
                                    style: TextStyle(
                                        color: Colors.black45, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: provider.items.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _tipSummary(provider.totalTips);
                            }
                            final item = provider.items[index - 1];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _historyCard(
                                service: item.service,
                                client: item.client,
                                total: '৳${item.total}',
                                tipAmount: item.tipAmount,
                                time: _formatTime(item.time),
                                status: _statusLabel(item.status),
                                color: _statusColor(item.status),
                              ),
                            );
                          },
                        ),
                ),
        );
      },
    );
  }

  Widget _tipSummary(int totalTips) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total tips earned',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            '৳$totalTips',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard({
    required String service,
    required String client,
    required String total,
    required int tipAmount,
    required String time,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                service,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            "Client: $client",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),

          if (tipAmount > 0) ...[
            const SizedBox(height: 6),
            Text(
              "Tip: ৳$tipAmount",
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 6),

          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;
    final isYesterday =
        time.difference(DateTime(now.year, now.month, now.day)).inDays == -1;

    // Convert to 12-hour AM/PM format
    int hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }
    final timeLabel = "$hour:${minute.toString().padLeft(2, '0')} $period";

    if (isToday) return "Today • $timeLabel";
    if (isYesterday) return "Yesterday • $timeLabel";
    return "${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} • $timeLabel";
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
      case 'done':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'serving':
        return 'Serving';
      default:
        return 'Waiting';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'serving':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }
}
