import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'package:cutline/shared/config/app_flavor.dart';

import 'package:cutline/firebase_options.dart' as prod_options;
import 'package:cutline/firebase_options_dev.dart' as dev_options;
import 'package:cutline/firebase_options_staging.dart' as staging_options;

class FirebaseOptionsByFlavor {
  static FirebaseOptions web(AppFlavor flavor) {
    final FirebaseOptions options = switch (flavor) {
      AppFlavor.dev => dev_options.DefaultFirebaseOptions.web,
      AppFlavor.staging => staging_options.DefaultFirebaseOptions.web,
      AppFlavor.prod => prod_options.DefaultFirebaseOptions.web,
    };

    if (_looksUnconfigured(options)) {
      throw StateError(
        'Firebase web options are not configured for flavor "${flavor.name}". '
        'Run FlutterFire CLI to generate the correct `lib/firebase_options_${flavor.name}.dart`.',
      );
    }

    return options;
  }

  static bool _looksUnconfigured(FirebaseOptions options) {
    return options.apiKey.trim().isEmpty ||
        options.appId.trim().isEmpty ||
        options.projectId.trim().isEmpty ||
        options.messagingSenderId.trim().isEmpty;
  }
}

