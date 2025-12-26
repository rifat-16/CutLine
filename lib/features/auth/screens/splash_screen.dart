import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/features/owner/services/salon_lookup_service.dart';
import 'package:cutline/shared/screens/update_required_screen.dart';
import 'package:cutline/shared/services/auth_session_storage.dart';
import 'package:cutline/shared/services/session_debug.dart';
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
        await auth.waitForAuthReady();
      } catch (_) {
        // Best-effort: on some devices FirebaseAuth may be slow to hydrate the
        // cached session. We'll still continue with whatever state we have.
      }
      // Best-effort refresh (do not block startup if network/Play services
      // are slow or restricted on some OEM devices).
      try {
        await auth.refreshCurrentUser()
            .timeout(const Duration(seconds: 12), onTimeout: () => null);
      } catch (_) {
        // Ignore.
      }

      if (!mounted) return;
      var user = auth.currentUser;
      if (user == null) {
        final msg = (auth.lastError ?? '').trim();
        String? banner = msg.isEmpty ? null : msg;
        String? lastUid;
        try {
          lastUid = await AuthSessionStorage().getLastSignedInUid();
          if (!mounted) return;
          if (lastUid != null) {
            banner ??=
                'Session was cleared on this device. If you are on Xiaomi/Redmi, set Battery saver for CutLine to "No restrictions" and enable Autostart, then try again.';
            SessionDebug.log('currentUser is null but last uid exists: $lastUid');
            SessionDebug.snack(context, 'Auth session missing; last uid: $lastUid');
          }
        } catch (e, st) {
          SessionDebug.log('Failed reading last signed-in uid',
              error: e, stackTrace: st);
          if (!mounted) return;
          SessionDebug.snack(context, 'Error reading session storage: $e');
        }
        // If we have remembered credentials (opt-in), attempt a silent login.
        // This is a fallback for OEM devices that wipe FirebaseAuth sessions.
        final restored = await _tryRememberedLogin(auth);
        if (!mounted) return;
        if (restored) {
          user = auth.currentUser;
        }

        if (user == null) {
          if (lastUid != null) {
            banner ??=
                'Please sign in again. If you are on Xiaomi/Redmi, set Battery saver for CutLine to "No restrictions" and enable Autostart.';
          }
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.roleSelection,
            arguments: banner,
          );
          return;
        }
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
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.roleSelection,
          arguments:
              'Signed in, but account data could not be loaded yet. Please try again.',
        );
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

  Future<bool> _tryRememberedLogin(AuthProvider auth) async {
    try {
      final creds = await AuthSessionStorage().getRememberedCredentials();
      if (creds == null) return false;

      const transientCodes = {'network-request-failed', 'internal-error', 'unknown'};
      for (var attempt = 0; attempt < 2; attempt++) {
        final ok = await auth
            .signIn(email: creds.email, password: creds.password)
            .timeout(const Duration(seconds: 12), onTimeout: () => false);
        if (ok) return true;

        final code = auth.lastAuthErrorCode ?? '';
        final invalid = code == 'wrong-password' ||
            code == 'user-not-found' ||
            code == 'invalid-credential' ||
            code == 'invalid-login-credentials';
        if (invalid) {
          await AuthSessionStorage().clearRememberedCredentials();
          return false;
        }
        if (!transientCodes.contains(code)) {
          return false;
        }
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      return false;
    } catch (e, st) {
      SessionDebug.log('Remembered login attempt failed',
          error: e, stackTrace: st);
      return false;
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
