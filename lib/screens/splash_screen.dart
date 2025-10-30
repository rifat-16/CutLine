import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection);
      return;
    }

    // Navigate based on role
    if (authProvider.isOwner) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.ownerDashboard);
    } else if (authProvider.isBarber) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.barberDashboard);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.userHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.content_cut,
                size: 80,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 32),
            
            // App Name
            const Text(
              'Cutline',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            
            // Tagline
            const Text(
              'Skip the waiting line',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
