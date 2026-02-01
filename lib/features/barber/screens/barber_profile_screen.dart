import 'dart:io';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_profile_provider.dart';
import 'package:cutline/features/barber/screens/work_history_screen.dart';
import 'package:cutline/features/barber/screens/barber_tips_screen.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'barber_edit_profile_screen.dart';

class BarberProfileScreen extends StatefulWidget {
  const BarberProfileScreen({super.key});

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  File? _imageFile;
  bool _profileUpdated = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider =
            BarberProfileProvider(authProvider: context.read<AuthProvider>());
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<BarberProfileProvider>();
        final profile = provider.profile;
        final name =
            profile?.name.isNotEmpty == true ? profile!.name : 'Barber';
        final title = profile?.specialization.isNotEmpty == true
            ? profile!.specialization
            : 'Hair Artist';
        final phone =
            profile?.phone.isNotEmpty == true ? profile!.phone : 'Not added';

        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context).pop(_profileUpdated);
            return false;
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Profile"),
              centerTitle: true,
              elevation: 0,
            ),
            body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (provider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      // PROFILE HEADER
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Builder(
                              builder: (context) {
                                ImageProvider? imageProvider;
                                if (_imageFile != null) {
                                  imageProvider = FileImage(_imageFile!);
                                } else if (provider.profile?.photoUrl != null &&
                                    provider.profile!.photoUrl.isNotEmpty) {
                                  imageProvider =
                                      NetworkImage(provider.profile!.photoUrl);
                                }
                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: imageProvider,
                                  child: imageProvider == null
                                      ? const Icon(Icons.person,
                                          size: 60, color: Colors.white)
                                      : null,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),
                      Text(
                        name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        title,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        phone,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),

                      const SizedBox(height: 30),

                      // SETTINGS
                      _settingTile(
                        icon: Icons.edit,
                        title: "Edit Profile",
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EditProfileScreen()),
                          );
                          if (!mounted) return;
                          if (updated == true) {
                            setState(() {
                              _profileUpdated = true;
                            });
                            context.read<BarberProfileProvider>().load();
                          }
                        },
                      ),
                      _settingTile(
                        icon: Icons.history,
                        title: "Work History",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const WorkHistoryScreen()),
                          );
                        },
                      ),
                      _settingTile(
                        icon: Icons.payments_outlined,
                        title: "My Tips",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const BarberTipsScreen()),
                          );
                        },
                      ),
                      _settingTile(
                        icon: Icons.logout,
                        title: "Logout",
                        color: Colors.red,
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ),
          ),
        );
      },
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    Color color = Colors.black,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    fontSize: 16, color: color, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await auth.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.barberLogin,
                (_) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
