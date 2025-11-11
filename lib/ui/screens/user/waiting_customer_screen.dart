import 'dart:async';
import 'package:flutter/material.dart';

class WaitingListScreen extends StatefulWidget {
  const WaitingListScreen({super.key});

  @override
  State<WaitingListScreen> createState() => _WaitingListScreenState();
}

class _WaitingListScreenState extends State<WaitingListScreen> {
  bool sortAscending = true;
  late Timer _timer;

  final List<Map<String, dynamic>> waitingList = [
    {
      "profile": "https://i.pravatar.cc/150?img=3",
      "name": "Rafi Ahmed",
      "barber": "Kamal",
      "service": "Haircut + Beard",
      "timeLeft": 12,
      "status": "In Queue",
    },
    {
      "profile": "https://i.pravatar.cc/150?img=4",
      "name": "Jihan Rahman",
      "barber": "Imran",
      "service": "Facial + Beard Trim",
      "timeLeft": 3,
      "status": "Serving Soon",
    },
    {
      "profile": "https://i.pravatar.cc/150?img=5",
      "name": "Tania Akter",
      "barber": "Sajjad",
      "service": "Hair Color",
      "timeLeft": 20,
      "status": "In Queue",
    },
  ];

  @override
  void initState() {
    super.initState();
    // Live countdown timer
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        for (var customer in waitingList) {
          if (customer["timeLeft"] > 0) customer["timeLeft"]--;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Serving Soon":
        return Colors.green;
      case "Cancelled":
        return Colors.red;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedList = List<Map<String, dynamic>>.from(waitingList);
    sortedList.sort((a, b) => sortAscending
        ? a["timeLeft"].compareTo(b["timeLeft"])
        : b["timeLeft"].compareTo(a["timeLeft"]));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Waiting for Service",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: "Sort by time",
            onPressed: () {
              setState(() {
                sortAscending = !sortAscending;
              });
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedList.length,
        itemBuilder: (context, index) {
          final item = sortedList[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile photo
                CircleAvatar(
                  backgroundImage: NetworkImage(item["profile"]),
                  radius: 28,
                ),
                const SizedBox(width: 12),

                // Info section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item["name"],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(item["status"])
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item["status"],
                              style: TextStyle(
                                color: _getStatusColor(item["status"]),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Barber: ${item["barber"]}",
                        style:
                        const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      Text(
                        "Service: ${item["service"]}",
                        style:
                        const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 4),
                          Text(
                            "${item["timeLeft"]} min left",
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueAccent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}