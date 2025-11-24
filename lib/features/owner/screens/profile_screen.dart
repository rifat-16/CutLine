import 'package:cutline/features/owner/screens/edit_profile_info_screen.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Owner profile'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const _ProfileCard(),
          const SizedBox(height: 24),
          const Text('Owner information',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          const _OwnerInfoSection(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('Logout'),
          )
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

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
                      child: Text(
                        kOwnerName.split(' ').map((e) => e[0]).take(2).join(),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB)),
                      ),
                    ),
                    Positioned(
                      bottom: -6,
                      right: -4,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _showEditPhotoSheet(context),
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
                  Text(kOwnerName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Owner • $kOwnerSalonName',
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
                  kOwnerSalonAddress,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => OwnerProfileScreen._open(
                context, const EditSalonInfoScreen()),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
        ],
      ),
    );
  }

  void _showEditPhotoSheet(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        Widget buildTile(IconData icon, String title, String subtitle) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF2563EB),
              child: Icon(icon),
            ),
            title: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            subtitle: Text(subtitle),
            onTap: () {
              Navigator.pop(sheetContext);
              messenger.showSnackBar(
                SnackBar(content: Text('$title option coming soon')),
              );
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Update profile picture',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Choose how you want to update your studio photo',
                  style: TextStyle(color: Colors.blueGrey.shade600)),
              const SizedBox(height: 8),
              buildTile(Icons.camera_alt_outlined, 'Take a photo',
                  'Use your camera to capture a new picture'),
              buildTile(Icons.photo_library_outlined, 'Choose from gallery',
                  'Pick an existing photo from your phone'),
              buildTile(Icons.delete_outline, 'Remove current photo',
                  'Revert to initials avatar'),
            ],
          ),
        );
      },
    );
  }
}

class _OwnerInfoSection extends StatelessWidget {
  const _OwnerInfoSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: const [
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Full name',
            value: kOwnerName,
          ),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Contact number',
            value: kOwnerSalonPhone,
          ),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email address',
            value: kOwnerSalonEmail,
          ),
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: 'Studio name',
            value: kOwnerSalonName,
          ),
          _InfoRow(
            icon: Icons.location_city_outlined,
            label: 'Studio address',
            value: kOwnerSalonAddress,
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
