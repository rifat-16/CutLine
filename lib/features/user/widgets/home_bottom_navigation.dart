import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeBottomNavigation extends StatelessWidget {
  final ValueChanged<int> onItemTapped;

  const HomeBottomNavigation({super.key, required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: CutlineColors.primary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8.h,
      backgroundColor: CutlineColors.background,
      onTap: onItemTapped,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.queue_outlined), activeIcon: Icon(Icons.queue), label: 'My Booking'),
        BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: 'Favorite'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
