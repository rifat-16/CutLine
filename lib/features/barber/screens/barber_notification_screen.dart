import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_notification_provider.dart';
import 'package:cutline/shared/models/app_notification.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class BarberNotificationScreen extends StatelessWidget {
  const BarberNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Notifications"),
          centerTitle: true,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Please sign in to view notifications'),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => BarberNotificationProvider(userId: userId),
      child: const _BarberNotificationContent(),
    );
  }
}

class _BarberNotificationContent extends StatelessWidget {
  const _BarberNotificationContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarberNotificationProvider>();

    if (provider.isLoading && provider.notifications.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Notifications"),
          centerTitle: true,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.notifications.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Notifications"),
          centerTitle: true,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none_rounded,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                "No notifications yet",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "You'll see notifications here when customers are waiting for you.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
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
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
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
  final BarberNotificationProvider provider;

  const _NotificationTile({
    required this.notification,
    required this.provider,
  });

  IconData _getIcon() {
    switch (notification.type) {
      case 'barber_waiting':
        return Icons.person_add;
      case 'booking_accepted':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case 'barber_waiting':
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
    if (notification.type == 'barber_waiting') {
      Navigator.of(context).pushNamed(AppRoutes.barberHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _handleTap(context),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notification.isRead ? Colors.white : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: notification.isRead
                    ? Colors.grey.shade300
                    : Colors.orange.shade200,
                width: notification.isRead ? 1 : 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getIconColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_getIcon(), color: _getIconColor(), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.w700
                                    : FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(notification.createdAt),
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
          ),
        ),
      ),
    );
  }
}
