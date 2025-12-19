import 'package:cutline/shared/services/notification_storage_service.dart';
import 'package:flutter/material.dart';

/// Notification bell with an unread badge for app bars
class NotificationBadgeIcon extends StatelessWidget {
  const NotificationBadgeIcon({
    super.key,
    required this.userId,
    required this.onTap,
    this.icon = Icons.notifications_none,
  });

  final String userId;
  final VoidCallback onTap;
  final IconData icon;
  static final NotificationStorageService _storageService =
      NotificationStorageService();

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return IconButton(
        icon: Icon(icon),
        tooltip: 'Notifications',
        onPressed: onTap,
      );
    }

    return StreamBuilder<int>(
      stream: _storageService.getUnreadCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(icon),
              tooltip: 'Notifications',
              onPressed: onTap,
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: _NotificationBadge(count: count),
              ),
          ],
        );
      },
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          display,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
