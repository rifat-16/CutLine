import 'package:flutter/material.dart';

class OwnerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const OwnerBottomNavBar(
      {super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: 'Queue'),
        BottomNavigationBarItem(
            icon: Icon(Icons.people_outline), label: 'Barbers'),
        BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined), label: 'Bookings'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    );
  }
}
