

import 'package:flutter/material.dart';

class BarberNotificationScreen extends StatelessWidget {
  const BarberNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _notificationTile(
            title: "New Client Added",
            subtitle: "A customer booked Haircut & Beard",
            time: "2 min ago",
            icon: Icons.person_add_alt_1,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _notificationTile(
            title: "Serving Completed",
            subtitle: "Your last client has been marked as done",
            time: "10 min ago",
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _notificationTile(
            title: "Reminder",
            subtitle: "Next appointment starts soon",
            time: "25 min ago",
            icon: Icons.alarm,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _notificationTile({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}