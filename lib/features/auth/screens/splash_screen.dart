import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/features/owner/services/salon_lookup_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNavigation();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startNavigation() async {
    // Keep a short splash experience before resolving auth state.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.refreshCurrentUser();

    if (!mounted) return;
    final user = auth.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
      return;
    }

    final profile = await auth.fetchUserProfile(user.uid);
    if (!mounted) return;

    final role = profile?['role'] != null
        ? UserRoleKey.fromKey(profile!['role'] as String? ?? 'customer')
        : UserRole.customer;
    final profileComplete = profile?['profileComplete'] == true;

    String target;
    switch (role) {
      case UserRole.owner:
        final hasSalon = await SalonLookupService().salonExists(user.uid);
        if (!hasSalon) {
          await auth.setProfileComplete(false);
        }
        target = profileComplete && hasSalon
            ? AppRoutes.ownerHome
            : AppRoutes.ownerSalonSetup;
        break;
      case UserRole.barber:
        target = AppRoutes.barberHome;
        break;
      default:
        target = AppRoutes.userHome;
        break;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 250,
            ),
          ],
        ),
      ),
    );
  }
}
