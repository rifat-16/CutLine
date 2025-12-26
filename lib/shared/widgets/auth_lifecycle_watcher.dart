import 'dart:async';

import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/services/auth_session_storage.dart';
import 'package:cutline/shared/services/session_debug.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthLifecycleWatcher extends StatefulWidget {
  const AuthLifecycleWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<AuthLifecycleWatcher> createState() => _AuthLifecycleWatcherState();
}

class _AuthLifecycleWatcherState extends State<AuthLifecycleWatcher>
    with WidgetsBindingObserver {
  DateTime? _lastResumeCheckAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    final last = _lastResumeCheckAt;
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _lastResumeCheckAt = now;
    unawaited(_checkSession());
  }

  Future<void> _checkSession() async {
    final auth = context.read<AuthProvider>();
    final beforeUid = auth.currentUser?.uid;
    await auth.refreshCurrentUser();
    if (!mounted) return;

    if (!SessionDebug.enabled) return;

    final afterUid = auth.currentUser?.uid;
    if (afterUid == null) {
      final lastUid = await AuthSessionStorage().getLastSignedInUid();
      if (!mounted) return;
      if (lastUid != null) {
        SessionDebug.snack(
          context,
          'Session cleared (last uid: $lastUid). MIUI may be wiping app storage.',
        );
      } else if (beforeUid != null) {
        SessionDebug.snack(context, 'Session lost on resume (uid: $beforeUid).');
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

