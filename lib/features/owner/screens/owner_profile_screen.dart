import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/edit_salon_provider.dart';
import 'package:cutline/features/owner/screens/owner_profile_edit_screen.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = EditSalonProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<EditSalonProvider>();
        final loading = provider.isLoading;
        final salonName = provider.salonName;
        final ownerName = provider.ownerName;
        final email = provider.email;
        final phone = provider.phone;
        final address = provider.address;
        final photoUrl = provider.photoUrl;
        final uploadingPhoto = provider.isUploadingPhoto;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            title: const Text('Owner profile'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    _ProfileCard(
                      ownerName: ownerName,
                      salonName: salonName,
                      address: address,
                      photoUrl: photoUrl,
                      isUploading: uploadingPhoto,
                    ),
                    const SizedBox(height: 24),
                    const Text('Owner information',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    _OwnerInfoSection(
                      ownerName: ownerName,
                      phone: phone,
                      email: email,
                      salonName: salonName,
                      address: address,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _confirmLogout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Logout'),
                    )
                  ],
                ),
        );
      },
    );
  }

  static Future<void> _open(BuildContext context, Widget screen) async {
    final provider = context.read<EditSalonProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    // Refresh profile data when returning from edit.
    await provider.load();
  }

  static void _confirmLogout(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Do you want to logout from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await auth.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.ownerLogin,
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.ownerName,
    required this.salonName,
    required this.address,
    required this.photoUrl,
    required this.isUploading,
  });

  final String ownerName;
  final String salonName;
  final String address;
  final String? photoUrl;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2FE), Color(0xFFDDEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage: isUploading
                          ? null
                          : (photoUrl != null && photoUrl!.isNotEmpty
                              ? NetworkImage(photoUrl!)
                              : null),
                      child: isUploading
                          ? const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2563EB)),
                            )
                          : (photoUrl == null || photoUrl!.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Color(0xFF2563EB),
                                  size: 28,
                                )
                              : null),
                    ),
                    if (!isUploading)
                      Positioned(
                        bottom: -6,
                        right: -4,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _handleUpload(context),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.camera_alt_outlined,
                                  size: 18, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ownerName.isEmpty ? 'Owner' : ownerName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Owner • ${salonName.isEmpty ? 'Salon' : salonName}',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address.isEmpty ? 'Add your salon address' : address,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => OwnerProfileScreen._open(
                context, const OwnerProfileEditScreen()),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
        ],
      ),
    );
  }

  void _handleUpload(BuildContext context) {
    context.read<EditSalonProvider>().uploadProfilePhoto();
  }
}

class _OwnerInfoSection extends StatelessWidget {
  const _OwnerInfoSection({
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.salonName,
    required this.address,
  });

  final String ownerName;
  final String phone;
  final String email;
  final String salonName;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Full name',
            value: ownerName.isEmpty ? 'Add your name' : ownerName,
          ),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Contact number',
            value: phone.isEmpty ? 'Add contact number' : phone,
          ),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email address',
            value: email.isEmpty ? 'Add email' : email,
          ),
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: 'Studio name',
            value: salonName.isEmpty ? 'Add studio name' : salonName,
          ),
          _InfoRow(
            icon: Icons.location_city_outlined,
            label: 'Studio address',
            value: address.isEmpty ? 'Add studio address' : address,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB)),
          ),
          title: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 0),
          ),
      ],
    );
  }
}
