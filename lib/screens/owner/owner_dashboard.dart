import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/salon_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final salonProvider = Provider.of<SalonProvider>(context);

    // Check if salon exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (salonProvider.currentSalon == null && authProvider.isAuthenticated) {
        // User doesn't have a salon yet, navigate to setup
        Navigator.of(context).pushReplacementNamed(AppRoutes.salonSetup);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(salonProvider.currentSalon?.name ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection);
              }
            },
          ),
        ],
      ),
      body: salonProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : salonProvider.currentSalon == null
              ? const Center(child: Text('Loading...'))
              : _buildDashboard(context, salonProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.addBarber);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Barber'),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, SalonProvider salonProvider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats Cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.person,
                label: 'Barbers',
                value: salonProvider.currentSalon!.barbers.length.toString(),
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.queue,
                label: 'Services',
                value: salonProvider.currentSalon!.services.length.toString(),
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Quick Actions
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        _ActionCard(
          icon: Icons.people,
          title: 'Manage Barbers',
          subtitle: 'Add, edit, or remove barbers',
          onTap: () {
            Navigator.of(context).pushNamed(AppRoutes.manageBarbers);
          },
        ),
        const SizedBox(height: 12),
        
        _ActionCard(
          icon: Icons.queue,
          title: 'Manage Queue',
          subtitle: 'View all salon queues',
          onTap: () {
            Navigator.of(context).pushNamed(AppRoutes.manageQueue);
          },
        ),
        const SizedBox(height: 12),
        
        _ActionCard(
          icon: Icons.store,
          title: 'Salon Settings',
          subtitle: 'Update salon information',
          onTap: () {
            // TODO: Navigate to settings
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryBlue),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
