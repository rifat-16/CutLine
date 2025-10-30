import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Logo
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.content_cut,
                    size: 60,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Welcome to Cutline',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              const Text(
                'Choose your role',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.gray600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // User Button
              _RoleButton(
                icon: Icons.person,
                title: 'User',
                description: 'Book slots and track your queue',
                color: AppColors.primaryBlue,
                onTap: () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                },
              ),
              const SizedBox(height: 16),
              
              // Barber Button
              _RoleButton(
                icon: Icons.face,
                title: 'Barber',
                description: 'Manage your own queue',
                color: AppColors.primaryOrange,
                onTap: () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                },
              ),
              const SizedBox(height: 16),
              
              // Owner Button
              _RoleButton(
                icon: Icons.store,
                title: 'Owner',
                description: 'Manage salon and barbers',
                color: AppColors.successGreen,
                onTap: () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                },
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
