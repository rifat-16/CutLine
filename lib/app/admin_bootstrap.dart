import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cutline/app/cutline_admin_app.dart';
import 'package:cutline/shared/config/app_flavor.dart';
import 'package:cutline/shared/services/firebase_options_by_flavor.dart';

Future<void> bootstrapAdmin({required AppFlavor flavor}) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptionsByFlavor.web(flavor),
    );
  } else {
    await Firebase.initializeApp();
  }

  final crashlyticsSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (crashlyticsSupported) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(CutLineAdminApp(flavor: flavor));
}
