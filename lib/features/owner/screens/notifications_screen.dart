import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/owner_notification_provider.dart';
import 'package:cutline/shared/models/app_notification.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class OwnerNotificationsScreen extends StatelessWidget {
  const OwnerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notification'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Please sign in to view notifications'),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => OwnerNotificationProvider(userId: userId),
      child: const _OwnerNotificationsContent(),
    );
  }
}

class _OwnerNotificationsContent extends StatelessWidget {
  const _OwnerNotificationsContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnerNotificationProvider>();

    if (provider.isLoading && provider.notifications.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notification'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.notifications.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          title: const Text('Notification'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none,
                      size: 42, color: Colors.indigo),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'You\'ll see booking requests and updates here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Group notifications by date
    final today = DateTime.now();
    final todayNotifications = provider.notifications.where((n) {
      return n.createdAt.year == today.year &&
          n.createdAt.month == today.month &&
          n.createdAt.day == today.day;
    }).toList();

    final earlierNotifications = provider.notifications
        .where((n) => !todayNotifications.contains(n))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Notification'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (provider.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () => provider.markAllAsRead(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh is handled by stream
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (todayNotifications.isNotEmpty) ...[
              const Text(
                'Today',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...todayNotifications.map((n) => _NotificationTile(
                    notification: n,
                    provider: provider,
                  )),
              const SizedBox(height: 24),
            ],
            if (earlierNotifications.isNotEmpty) ...[
              const Text(
                'Earlier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...earlierNotifications.map((n) => _NotificationTile(
                    notification: n,
                    provider: provider,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final OwnerNotificationProvider provider;

  const _NotificationTile({
    required this.notification,
    required this.provider,
  });

  IconData _getIcon() {
    switch (notification.type) {
      case 'booking_request':
        return Icons.event_available;
      case 'booking_accepted':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case 'booking_request':
        return Colors.orange;
      case 'booking_accepted':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }

  void _handleTap(BuildContext context) {
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    // Navigate based on notification type
    if (notification.type == 'booking_request') {
      Navigator.of(context).pushNamed(AppRoutes.ownerBookingRequests);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead
              ? Colors.grey.shade300
              : Colors.blue.shade200,
          width: notification.isRead ? 1 : 1.5,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getIconColor().withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getIcon(), color: _getIconColor(), size: 24),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            notification.body,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(notification.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        onTap: () => _handleTap(context),
      ),
    );
  }
}
