enum AppFlavor {
  dev,
  staging,
  prod,
}

extension AppFlavorX on AppFlavor {
  String get name {
    switch (this) {
      case AppFlavor.dev:
        return 'dev';
      case AppFlavor.staging:
        return 'staging';
      case AppFlavor.prod:
        return 'prod';
    }
  }

  String get displayName {
    switch (this) {
      case AppFlavor.dev:
        return 'CutLine Dev';
      case AppFlavor.staging:
        return 'CutLine Staging';
      case AppFlavor.prod:
        return 'CutLine';
    }
  }
}

