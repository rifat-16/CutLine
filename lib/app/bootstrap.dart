import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'package:cutline/app/cutline_app.dart';
import 'package:cutline/shared/config/app_flavor.dart';
import 'package:cutline/shared/services/notification_service.dart';

import 'package:cutline/shared/services/firebase_options_by_flavor.dart';

Future<void> bootstrap({required AppFlavor flavor}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Helps avoid blank/black GoogleMap rendering on some Android devices.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
    }
  }

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

  await notificationService.initialize();

  runApp(CutLineApp(flavor: flavor));
}
