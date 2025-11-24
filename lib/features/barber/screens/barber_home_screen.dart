import 'package:flutter/material.dart';

import 'barber_notification_screen.dart';
import 'barber_profile_screen.dart';

class BarberHomeScreen extends StatefulWidget {
  const BarberHomeScreen({super.key});

  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BarberNotificationScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BarberProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusCard("Waiting", "2", "clients", Colors.orange),
                _buildStatusCard("Serving", "1", "in chairs", Colors.blue),
                _buildStatusCard("Completed", "1", "today", Colors.green),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Live queue",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _queueTab("Waiting", true),
                _queueTab("Serving", false),
                _queueTab("Completed", false),
              ],
            ),
            const SizedBox(height: 20),
            _buildQueueCard(),
          ],
        ),
      ),
    );
  }
}

Widget _buildStatusCard(String title, String count, String label, Color color) {
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
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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

Widget _buildQueueCard() {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("Tahmid Hasan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("12 min", style: TextStyle(color: Colors.orange, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 8),
        const Text("Haircut & Beard • ৳480   Token #12", style: TextStyle(color: Colors.black54, fontSize: 14)),
        const SizedBox(height: 6),
        const Text("Barber: Alex", style: TextStyle(color: Colors.black54, fontSize: 14)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text("Waiting", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {},
            child: const Text("Start Serving", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ),
  );
}
