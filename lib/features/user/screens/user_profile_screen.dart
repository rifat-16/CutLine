import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  static const String _userName = 'Boss Ahmed';
  static const String _userPhone = '+8801XXXXXXX';
  static const int _loyaltyPoints = 230;
  static const String _membershipTier = 'Gold Member';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CutlineAppBar(title: 'Profile', centerTitle: true),
      backgroundColor: CutlineColors.secondaryBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            const _ProfileHeader(name: _userName, phoneNumber: _userPhone),
            const SizedBox(height: CutlineSpacing.md),
            const _ProfileChip(
                points: _loyaltyPoints, tierLabel: _membershipTier),
            const SizedBox(height: CutlineSpacing.lg),
            _ProfileSection(title: 'Account', items: [
              _ProfileTile(
                icon: Icons.edit_outlined,
                label: 'Edit Profile',
                subtitle: 'Change personal details',
                onTap: () => _showUnavailableFeature(context),
              ),
              _ProfileTile(
                icon: Icons.calendar_today_outlined,
                label: 'My Bookings',
                subtitle: 'See upcoming and past visits',
                onTap: () => _openRoute(context, AppRoutes.myBookings),
              ),
              _ProfileTile(
                icon: Icons.favorite_border_outlined,
                label: 'Saved Salons',
                subtitle: 'Manage your favourites',
                onTap: () => _openRoute(context, AppRoutes.favoriteSalons),
              ),
              _ProfileTile(
                icon: Icons.notifications_none_outlined,
                label: 'Notifications',
                subtitle: 'Manage alerts',
                onTap: () => _openRoute(context, AppRoutes.userNotifications),
              ),
            ]),
            const SizedBox(height: CutlineSpacing.lg),
            _ProfileSection(title: 'Support', items: [
              _ProfileTile(
                icon: Icons.help_outline,
                label: 'Help & Support',
                subtitle: 'Chat with the Cutline team',
                onTap: () => _showSupportSheet(context),
              ),
              _ProfileTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                subtitle: 'Understand how we use your data',
                onTap: () => _showPrivacySheet(context),
              ),
            ]),
            const SizedBox(height: CutlineSpacing.lg),
            _LogoutButton(onPressed: () => _confirmLogout(context)),
            const SizedBox(height: CutlineSpacing.lg),
          ],
        ),
      ),
    );
  }

  static void _openRoute(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  static void _showUnavailableFeature(BuildContext context) {
    _showSnack(context, 'Profile editing will be available soon.');
  }

  static void _showSupportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help?',
                style: CutlineTextStyles.title.copyWith(fontSize: 20)),
            const SizedBox(height: CutlineSpacing.sm),
            const Text(
                'Our support team is ready to jump in 9AM - 10PM (GMT+6).',
                style: CutlineTextStyles.body),
            const SizedBox(height: CutlineSpacing.md),
            _SupportTile(
              icon: Icons.chat_bubble_outline,
              title: 'Chat with us',
              subtitle: 'Average reply time • under 5 min',
            ),
            _SupportTile(
              icon: Icons.email_outlined,
              title: 'Email support@cutline.app',
              subtitle: 'We reply within 1 business day',
            ),
            _SupportTile(
              icon: Icons.phone_outlined,
              title: 'Call +880 1234-567890',
              subtitle: 'Press 2 for premium members',
            ),
          ],
        ),
      ),
    );
  }

  static void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Privacy at Cutline', style: CutlineTextStyles.title),
            SizedBox(height: CutlineSpacing.sm),
            Text(
              'We only store the data that keeps your bookings in sync. Your queue position, contact info, and favourite salons never leave our secure servers.',
              style: CutlineTextStyles.body,
            ),
            SizedBox(height: CutlineSpacing.sm),
            Text(
              'Need the full policy? Visit cutline.app/privacy or contact support@cutline.app.',
              style: CutlineTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  static void _confirmLogout(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content:
            const Text('Are you sure you want to logout from this device?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style: CutlineButtons.primary(),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await auth.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.roleSelection,
                (_) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SupportTile(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CutlineColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: CutlineColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CutlineTextStyles.subtitleBold),
                const SizedBox(height: 2),
                Text(subtitle, style: CutlineTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String phoneNumber;

  const _ProfileHeader({required this.name, required this.phoneNumber});

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    return parts.map((part) => part[0]).take(2).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140,
        ),
        Positioned(
          bottom: -40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor:
                      CutlineColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    _initials,
                    style: CutlineTextStyles.title
                        .copyWith(fontSize: 28, color: CutlineColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: CutlineSpacing.sm),
              Text(name, style: CutlineTextStyles.title.copyWith(fontSize: 22)),
              const SizedBox(height: 4),
              Text(phoneNumber, style: CutlineTextStyles.subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final int points;
  final String tierLabel;

  const _ProfileChip({required this.points, required this.tierLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: CutlineColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: CutlineColors.primary, size: 20),
          const SizedBox(width: 8),
          Text('Loyalty Points: $points',
              style: CutlineTextStyles.subtitleBold),
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tierLabel,
              style: CutlineTextStyles.caption.copyWith(
                  color: CutlineColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_ProfileTile> items;

  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: CutlineTextStyles.caption.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: CutlineSpacing.sm),
          ...items,
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  const _ProfileTile(
      {required this.icon, required this.label, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: CutlineColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: CutlineColors.primary, size: 22),
        ),
        title: Text(label,
            style: CutlineTextStyles.body
                .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle!, style: CutlineTextStyles.caption)
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LogoutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CutlineSpacing.section,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: CutlineButtons.primary(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 18)),
          onPressed: onPressed,
          icon: const Icon(Icons.logout, size: 24),
          label: const Text(
            'Logout',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
