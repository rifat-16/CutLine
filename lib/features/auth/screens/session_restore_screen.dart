import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/services/salon_lookup_service.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/services/auth_session_storage.dart';
import 'package:cutline/shared/services/session_debug.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionRestoreScreen extends StatefulWidget {
  const SessionRestoreScreen({super.key, this.reason});

  final String? reason;

  @override
  State<SessionRestoreScreen> createState() => _SessionRestoreScreenState();
}

class _SessionRestoreScreenState extends State<SessionRestoreScreen>
    with WidgetsBindingObserver {
  bool _isRestoring = false;
  String? _lastError;
  bool _attemptedRememberedLogin = false;
  bool _hadRememberedCredentials = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restore());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isRestoring) {
      unawaited(_restore());
    }
  }

  Future<void> _restore() async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
      _lastError = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      await auth.waitForAuthReady(timeout: const Duration(seconds: 12));
    } catch (_) {
      // Best-effort.
    }
    var user = auth.currentUser;
    if (user == null) {
      // Fallback for OEM devices that wipe FirebaseAuth sessions: if the user
      // opted into "Remember me", try a silent sign-in once per screen mount.
      if (!_attemptedRememberedLogin) {
        _attemptedRememberedLogin = true;
        try {
          final storage = AuthSessionStorage();
          final creds = await storage.getRememberedCredentials();
          _hadRememberedCredentials = creds != null;
          if (creds != null) {
            final ok = await auth
                .signIn(email: creds.email, password: creds.password)
                .timeout(const Duration(seconds: 12), onTimeout: () => false);
            if (ok) {
              user = auth.currentUser;
            } else {
              final code = auth.lastAuthErrorCode ?? '';
              final invalid = code == 'wrong-password' ||
                  code == 'user-not-found' ||
                  code == 'invalid-credential' ||
                  code == 'invalid-login-credentials';
              // Clear only when credentials are definitely invalid. For
              // transient failures (network/Play services), keep them so the
              // user can tap Retry without retyping.
              if (invalid) {
                await storage.clearRememberedCredentials();
              }
            }
          }
        } catch (_) {
          // Ignore; user can still manually sign in.
        }
      }
    }

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _lastError = auth.lastError ??
            (_hadRememberedCredentials
                ? 'Could not sign you in automatically. Tap Retry or sign in manually.'
                : 'Please sign in to continue.');
      });
      return;
    }

    try {
      Map<String, dynamic>? profile;

      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 12));
        if (snap.exists) profile = snap.data();
      } on TimeoutException catch (e, st) {
        SessionDebug.log('restore: profile fetch timed out',
            error: e, stackTrace: st);
      }

      profile ??= await auth
          .fetchUserProfile(user.uid)
          .timeout(const Duration(seconds: 12), onTimeout: () => null);

      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _lastError =
              'Could not load your account data. Check your connection and try again.';
        });
        SessionDebug.snack(context, 'Profile load failed; user is still signed in.');
        return;
      }

      final roleKey = profile['role'] as String?;
      final role =
          roleKey != null ? UserRoleKey.fromKey(roleKey) : UserRole.customer;
      final profileComplete = profile['profileComplete'] == true;

      final hasSalon = await SalonLookupService()
          .salonExists(user.uid)
          .timeout(const Duration(seconds: 12), onTimeout: () => false);
      if (!mounted) return;

      String target;
      switch (role) {
        case UserRole.owner:
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

      Navigator.pushNamedAndRemoveUntil(context, target, (_) => false);
    } catch (e, st) {
      SessionDebug.log('restore: unexpected failure', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _lastError =
            'Unable to restore your session right now. Please try again.';
      });
      SessionDebug.snack(context, 'Session restore error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = (widget.reason ?? '').trim();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Restoring session…',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (_lastError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _lastError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isRestoring ? null : () => unawaited(_restore()),
                  child: _isRestoring
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Retry'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _isRestoring
                      ? null
                      : () async {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.roleSelection,
                            (_) => false,
                          );
                        },
                  child: const Text('Go to login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
