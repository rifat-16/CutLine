import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/features/owner/services/salon_lookup_service.dart';
import 'package:cutline/shared/screens/update_required_screen.dart';
import 'package:cutline/shared/services/update_gate_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

    try {
      final updateResult = await UpdateGateService()
          .checkForUpdate()
          .timeout(const Duration(seconds: 12), onTimeout: () {
        return const UpdateGateResult(
          isRequired: false,
          message: '',
          minBuildNumber: 0,
          minVersion: '',
        );
      });
      if (!mounted) return;
      if (updateResult.isRequired) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UpdateRequiredScreen(
              message: updateResult.message,
            ),
          ),
        );
        return;
      }

      final auth = context.read<AuthProvider>();
      try {
        await auth.refreshCurrentUser().timeout(const Duration(seconds: 12));
      } on TimeoutException {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
        return;
      }

      if (!mounted) return;
      final user = auth.currentUser;
      if (user == null) {
        final msg = (auth.lastError ?? '').trim();
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.roleSelection,
          arguments: msg.isEmpty ? null : msg,
        );
        return;
      }

      Map<String, dynamic>? profile;
      try {
        DocumentSnapshot<Map<String, dynamic>>? profileSnap;
        try {
          profileSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 12));
        } on TimeoutException {
          profileSnap = null;
        }
        if (!mounted) return;

        if (profileSnap != null) {
          if (!profileSnap.exists) {
            await auth.signOut();
            if (!mounted) return;
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.roleSelection,
              arguments:
                  'Account data was removed. Please sign up again to continue.',
            );
            return;
          }
          profile = profileSnap.data();
        }
      } on FirebaseException {
        profile = null;
      } catch (_) {
        profile = null;
      }
      if (!mounted) return;

      // If we couldn't fetch the profile from server (timeout/network), fall
      // back to a normal fetch to avoid logging the user out unnecessarily.
      if (profile == null) {
        profile = await auth
            .fetchUserProfile(user.uid)
            .timeout(const Duration(seconds: 12), onTimeout: () => null);
        if (!mounted) return;
      }

      // If we still can't resolve a profile, fall back to the welcome flow.
      // (We don't force a sign-out here because it may be a transient network
      // failure; invalid/deleted auth sessions are handled by refreshCurrentUser
      // and the server-profile check above.)
      if (profile == null) {
        Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
        return;
      }

      final hasSalon = await SalonLookupService()
          .salonExists(user.uid)
          .timeout(const Duration(seconds: 12), onTimeout: () => false);
      if (!mounted) return;

      final roleKey = profile['role'] as String?;
      final role =
          roleKey != null ? UserRoleKey.fromKey(roleKey) : UserRole.customer;
      final profileComplete = profile['profileComplete'] == true;

      String target;
      switch (role) {
        case UserRole.owner:
          if (!hasSalon) {
            unawaited(
              auth.setProfileComplete(false).timeout(
                    const Duration(seconds: 8),
                    onTimeout: () => null,
                  ),
            );
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
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
    }
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
