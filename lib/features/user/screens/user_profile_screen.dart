import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cutline/features/owner/screens/contact_support_screen.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final user = auth.currentUser;

    final profileName = profile?.name.trim();
    final name = (profileName != null && profileName.isNotEmpty)
        ? profileName
        : (user != null && user.displayName?.trim().isNotEmpty == true
            ? user.displayName!
            : 'Guest');
    final profilePhone = profile?.phone?.trim();
    final phone = (profilePhone != null && profilePhone.isNotEmpty)
        ? profilePhone
        : (user?.phoneNumber ?? 'Phone not added');
    final profileEmail = profile?.email.trim();
    final email = (profileEmail != null && profileEmail.isNotEmpty)
        ? profileEmail
        : (user?.email ?? 'Email not added');

    return Scaffold(
      appBar: const CutlineAppBar(title: 'Profile', centerTitle: true),
      backgroundColor: CutlineColors.secondaryBackground,
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => auth.refreshCurrentUser(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: CutlineSpacing.section.copyWith(bottom: 24),
                children: [
          _ProfileHeaderCard(
            name: name,
            email: email,
            phone: phone,
            onEdit: () => Navigator.pushNamed(
              context,
              AppRoutes.userEditProfile,
            ),
            onAvatarTap: () => _showComingSoon(context),
          ),
                  const SizedBox(height: CutlineSpacing.md),
                  const _LoyaltyCardComingSoon(),
                  const SizedBox(height: CutlineSpacing.md),
                  _InfoCard(
                    title: 'Personal Info',
                    rows: [
                      _InfoRow(icon: Icons.person_outline, label: 'Name', value: name),
                      _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: phone),
                      _InfoRow(icon: Icons.email_outlined, label: 'Email', value: email),
                    ],
                  ),
                  const SizedBox(height: CutlineSpacing.md),
                  _SupportCard(
                    onSupport: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactSupportScreen(),
                      ),
                    ),
                    onPrivacy: () => _showPrivacySheet(context),
                  ),
                  const SizedBox(height: CutlineSpacing.lg),
                  _LogoutButton(onPressed: () => _confirmLogout(context)),
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
            Text('Privacy at CutLine', style: CutlineTextStyles.title),
            SizedBox(height: CutlineSpacing.sm),
            Text(
              'We only store the data that keeps your bookings in sync. Your queue position, contact info, and favourites stay secure.',
              style: CutlineTextStyles.body,
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
  static void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Profile photo upload coming soon.')),
      );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final VoidCallback? onEdit;
  final VoidCallback? onAvatarTap;

  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.phone,
    this.onEdit,
    this.onAvatarTap,
  });

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    return parts.map((part) => part[0]).take(2).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CutlineDecorations.card(
        colors: [CutlineColors.primary.withValues(alpha: 0.08), Colors.white],
      ),
      padding: CutlineSpacing.card,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: CutlineColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    _initials,
                    style: CutlineTextStyles.title
                        .copyWith(fontSize: 22, color: CutlineColors.primary),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(Icons.photo_camera_outlined,
                        size: 16, color: CutlineColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: CutlineSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: CutlineTextStyles.title.copyWith(fontSize: 20)),
                const SizedBox(height: 4),
                Text(email, style: CutlineTextStyles.subtitle),
                const SizedBox(height: 2),
                Text(phone, style: CutlineTextStyles.caption),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
            ),
        ],
      ),
    );
  }
}

class _LoyaltyCardComingSoon extends StatelessWidget {
  const _LoyaltyCardComingSoon();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CutlineDecorations.card(
        colors: [CutlineColors.primary.withValues(alpha: 0.08), Colors.white],
      ),
      padding: CutlineSpacing.card,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.emoji_events, color: CutlineColors.primary),
          ),
          const SizedBox(width: CutlineSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Loyalty Points',
                    style: CutlineTextStyles.subtitleBold
                        .copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Coming soon',
                    style: CutlineTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      padding: CutlineSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CutlineTextStyles.title.copyWith(fontSize: 18)),
          const SizedBox(height: CutlineSpacing.sm),
          ...rows.expand((row) => [
                row,
                if (row != rows.last)
                  const Divider(height: 16, thickness: 0.6)
              ]),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CutlineColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: CutlineColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: CutlineTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: CutlineTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportCard extends StatelessWidget {
  final VoidCallback onSupport;
  final VoidCallback onPrivacy;

  const _SupportCard({required this.onSupport, required this.onPrivacy});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      padding: CutlineSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Support & Privacy',
              style: CutlineTextStyles.title.copyWith(fontSize: 18)),
          const SizedBox(height: CutlineSpacing.sm),
          GestureDetector(
            onTap: onSupport,
            child: const _SupportTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Chat with the CutLine team',
            ),
          ),
          const Divider(height: 16, thickness: 0.6),
          GestureDetector(
            onTap: onPrivacy,
            child: const _SupportTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Understand how we use your data',
            ),
          ),
        ],
      ),
    );
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
    return Row(
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
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LogoutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: CutlineButtons.primary(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18)),
        onPressed: onPressed,
        icon: const Icon(Icons.logout, size: 24),
        label: const Text(
          'Logout',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
