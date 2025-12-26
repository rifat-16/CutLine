import 'package:flutter/material.dart';

class SessionDebug {
  static const enabled =
      bool.fromEnvironment('SESSION_DEBUG', defaultValue: false);

  static void log(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[session] $message');
    if (error != null) debugPrint('[session] error: $error');
    if (stackTrace != null) debugPrint('[session] stack: $stackTrace');
  }

  static void snack(BuildContext context, String message) {
    if (!enabled) return;
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      // Ignore; diagnostics should never crash the app.
    }
  }
}
