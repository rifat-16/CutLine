import 'dart:math';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateGateResult {
  const UpdateGateResult({
    required this.isRequired,
    required this.message,
    required this.minBuildNumber,
    required this.minVersion,
  });

  final bool isRequired;
  final String message;
  final int minBuildNumber;
  final String minVersion;
}

class UpdateGateService {
  UpdateGateService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  Future<UpdateGateResult> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final currentVersion = info.version;

      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(minutes: 15),
        ),
      );
      await _remoteConfig.setDefaults(const {
        'min_build_number': '1',
        'min_version': '1.0.0',
        'update_message': 'A new version is available. Please update to continue.',
      });
      await _remoteConfig.fetchAndActivate();

      final minBuild =
          int.tryParse(_remoteConfig.getString('min_build_number')) ?? 0;
      final minVersion = _remoteConfig.getString('min_version').trim();
      final message = _remoteConfig.getString('update_message').trim();

      final requiresUpdate =
          currentBuild < minBuild || _isVersionLower(currentVersion, minVersion);

      return UpdateGateResult(
        isRequired: requiresUpdate,
        message: message.isEmpty
            ? 'A new version is available. Please update to continue.'
            : message,
        minBuildNumber: minBuild,
        minVersion: minVersion.isEmpty ? '1.0.0' : minVersion,
      );
    } catch (_) {
      return const UpdateGateResult(
        isRequired: false,
        message: '',
        minBuildNumber: 0,
        minVersion: '',
      );
    }
  }

  bool _isVersionLower(String current, String minimum) {
    if (minimum.isEmpty) {
      return false;
    }
    final currentParts = _parseVersion(current);
    final minimumParts = _parseVersion(minimum);
    final length = max(currentParts.length, minimumParts.length);
    for (var i = 0; i < length; i++) {
      final currentValue = i < currentParts.length ? currentParts[i] : 0;
      final minimumValue = i < minimumParts.length ? minimumParts[i] : 0;
      if (currentValue < minimumValue) {
        return true;
      }
      if (currentValue > minimumValue) {
        return false;
      }
    }
    return false;
  }

  List<int> _parseVersion(String version) {
    final clean = version.split('+').first.trim();
    return clean
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
