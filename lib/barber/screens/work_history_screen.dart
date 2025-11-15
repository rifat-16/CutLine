import 'package:flutter/material.dart';

class WorkHistoryScreen extends StatelessWidget {
  const WorkHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Work History"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _historyCard(
            service: "Haircut & Beard",
            client: "Tahmid Hasan",
            price: "৳480",
            time: "Today • 2:45 PM",
            status: "Completed",
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _historyCard(
            service: "Haircut",
            client: "Rakib Ahmed",
            price: "৳250",
            time: "Yesterday • 6:10 PM",
            status: "Completed",
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _historyCard(
            service: "Beard Trim",
            client: "Nabil Khan",
            price: "৳150",
            time: "2 days ago • 4:00 PM",
            status: "Cancelled",
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _historyCard({
    required String service,
    required String client,
    required String price,
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
                price,
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
}
