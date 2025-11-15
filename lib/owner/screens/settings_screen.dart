import 'package:cutline/owner/screens/edit_profile_info_screen.dart';
import 'package:cutline/owner/screens/manage_services_screen.dart';
import 'package:cutline/owner/screens/working_hours_screen.dart';
import 'package:flutter/material.dart';

class OwnerSettingsScreen extends StatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  State<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends State<OwnerSettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const Text('Business',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          _SettingTile(
            icon: Icons.design_services_outlined,
            title: 'Manage services',
            subtitle: 'Add, edit or remove services',
            onTap: () => _open(const ManageServicesScreen()),
          ),
          _SettingTile(
            icon: Icons.schedule_outlined,
            title: 'Working hours',
            subtitle: 'Set daily availability',
            onTap: () => _open(const WorkingHoursScreen()),
          ),
          _SettingTile(
            icon: Icons.storefront_outlined,
            title: 'Edit salon info',
            subtitle: 'Name, address & contact',
            onTap: () => _open(const EditSalonInfoScreen()),
          ),
          const SizedBox(height: 24),
          const Text('Support',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Support request sent! We will email you.')));
              },
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.support_agent, color: Color(0xFF2563EB)),
              ),
              title: const Text('Contact support'),
              subtitle: const Text('We usually reply within a few hours'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
