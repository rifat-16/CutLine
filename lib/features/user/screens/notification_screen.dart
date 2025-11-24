import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static final List<_NotificationItem> _todayNotifications = [
    const _NotificationItem(
      icon: Icons.check_circle_outline,
      title: 'Booking Confirmed',
      message: 'Your booking at Hair Studio is confirmed.',
      time: '5m ago',
    ),
    const _NotificationItem(
      icon: Icons.alarm,
      title: 'Almost Your Turn!',
      message: 'Your turn is in 10 minutes. Please be ready.',
      time: '30m ago',
    ),
  ];

  static final List<_NotificationItem> _earlierNotifications = [
    const _NotificationItem(
      icon: Icons.local_offer_outlined,
      title: 'Special Offer 🎉',
      message: 'Get 20% off on your next haircut!',
      time: 'Yesterday',
    ),
    const _NotificationItem(
      icon: Icons.update,
      title: 'App Update',
      message: 'We added new features and bug fixes!',
      time: '2d ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CutlineAppBar(title: 'Notifications', centerTitle: true),
      backgroundColor: CutlineColors.secondaryBackground,
      body: ListView(
        padding: CutlineSpacing.section.copyWith(top: 20, bottom: 32),
        children: [
          const Text('Today', style: CutlineTextStyles.title),
          const SizedBox(height: CutlineSpacing.sm),
          ..._todayNotifications.asMap().entries.map(
            (entry) => CutlineAnimations.staggeredList(
              index: entry.key,
              child: _NotificationTile(item: entry.value),
            ),
          ),
          const SizedBox(height: CutlineSpacing.lg),
          const Text('Earlier', style: CutlineTextStyles.title),
          const SizedBox(height: CutlineSpacing.sm),
          ..._earlierNotifications.asMap().entries.map(
            (entry) => CutlineAnimations.staggeredList(
              index: entry.key,
              child: _NotificationTile(item: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _NotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CutlineSpacing.sm),
      decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: CutlineColors.primary.withValues(alpha: 0.1),
          child: Icon(item.icon, color: CutlineColors.primary),
        ),
        title: Text(item.title, style: CutlineTextStyles.subtitleBold),
        subtitle: Text(item.message, style: CutlineTextStyles.caption.copyWith(fontSize: 13)),
        trailing: Text(item.time, style: CutlineTextStyles.caption),
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String message;
  final String time;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
  });
}
