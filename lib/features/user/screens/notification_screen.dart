import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/notification_provider.dart';
import 'package:cutline/shared/models/app_notification.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: const CutlineAppBar(title: 'Notifications', centerTitle: true),
        body: const Center(
          child: Text('Please sign in to view notifications'),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => NotificationProvider(userId: userId),
      child: const _NotificationScreenContent(),
    );
  }
}

class _NotificationScreenContent extends StatelessWidget {
  const _NotificationScreenContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    if (provider.isLoading && provider.notifications.isEmpty) {
      return Scaffold(
        appBar: const CutlineAppBar(title: 'Notifications', centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.notifications.isEmpty) {
      return Scaffold(
        appBar: const CutlineAppBar(title: 'Notifications', centerTitle: true),
        backgroundColor: CutlineColors.secondaryBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ll see notifications here when you receive them',
                style: TextStyle(color: Colors.grey.shade600),
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
      appBar: CutlineAppBar(
        title: 'Notifications',
        centerTitle: true,
        actions: [
          if (provider.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () => provider.markAllAsRead(),
            ),
        ],
      ),
      backgroundColor: CutlineColors.secondaryBackground,
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh is handled by stream
        },
        child: ListView(
          padding: CutlineSpacing.section.copyWith(top: 20, bottom: 32),
          children: [
            if (todayNotifications.isNotEmpty) ...[
              const Text('Today', style: CutlineTextStyles.title),
              const SizedBox(height: CutlineSpacing.sm),
              ...todayNotifications.asMap().entries.map(
                    (entry) => CutlineAnimations.staggeredList(
                      index: entry.key,
                      child: _NotificationTile(
                        notification: entry.value,
                        provider: provider,
                      ),
                    ),
                  ),
              const SizedBox(height: CutlineSpacing.lg),
            ],
            if (earlierNotifications.isNotEmpty) ...[
              const Text('Earlier', style: CutlineTextStyles.title),
              const SizedBox(height: CutlineSpacing.sm),
              ...earlierNotifications.asMap().entries.map(
                    (entry) => CutlineAnimations.staggeredList(
                      index: entry.key,
                      child: _NotificationTile(
                        notification: entry.value,
                        provider: provider,
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final NotificationProvider provider;

  const _NotificationTile({
    required this.notification,
    required this.provider,
  });

  IconData _getIcon() {
    switch (notification.type) {
      case 'booking_request':
        return Icons.event_available;
      case 'booking_accepted':
        return Icons.check_circle_outline;
      case 'barber_waiting':
        return Icons.person;
      default:
        return Icons.notifications;
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
    if (notification.bookingId != null && notification.salonId != null) {
      if (notification.type == 'booking_accepted') {
        Navigator.of(context).pushNamed(
          AppRoutes.bookingReceipt,
          arguments: BookingReceiptArgs(
            salonId: notification.salonId!,
            bookingId: notification.bookingId!,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CutlineSpacing.sm),
      decoration: CutlineDecorations.card(
        solidColor: notification.isRead
            ? CutlineColors.background
            : CutlineColors.primary.withValues(alpha: 0.05),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: CutlineColors.primary.withValues(alpha: 0.1),
          child: Icon(_getIcon(), color: CutlineColors.primary),
        ),
        title: Text(
          notification.title,
          style: CutlineTextStyles.subtitleBold.copyWith(
            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          notification.body,
          style: CutlineTextStyles.caption.copyWith(fontSize: 13),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(notification.createdAt),
              style: CutlineTextStyles.caption,
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: CutlineColors.primary,
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
