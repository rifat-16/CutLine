# 🚀 How to Run the Cutline App

## Quick Start

Since Flutter needs to be properly installed and configured, follow these steps:

## 1. Install Flutter (if not already installed)

### On macOS:
```bash
# Download Flutter from https://flutter.dev/docs/get-started/install/macos
# Extract and add to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

## 2. Install Dependencies

```bash
cd /Users/rifat/StudioProjects/CutLine
flutter pub get
```

## 3. Connect Device or Start Emulator

### For Android:
```bash
# Start Android emulator or connect physical device
flutter emulators --launch <emulator-name>
# OR connect your phone via USB and enable USB debugging
```

### For iOS (macOS only):
```bash
# Open Simulator
open -a Simulator
```

## 4. Run the App

```bash
flutter run --flavor staging -t lib/main_staging.dart
```

## Flavors (dev / staging / prod)

This project uses 3 separate environments, and each environment uses a separate Firebase project.

### Android Firebase config (required per flavor)

- `android/app/src/dev/google-services.json`
- `android/app/src/staging/google-services.json`
- `android/app/src/prod/google-services.json`

Android package names:
- `dev`: `com.cutline.dev`
- `staging`: `com.cutline.staging`
- `prod`: `com.cutline.prod`

### iOS Firebase config (required per flavor)

- `ios/Runner/Firebase/GoogleService-Info-dev.plist`
- `ios/Runner/Firebase/GoogleService-Info-staging.plist`
- `ios/Runner/Firebase/GoogleService-Info-prod.plist`

iOS bundle identifiers:
- `dev`: `com.cutline.dev`
- `staging`: `com.cutline.staging`
- `prod`: `com.cutline.prod`

After adding/updating iOS configs, run:
```bash
cd ios
pod install
cd ..
```

### FlutterFire (web only)

Web initialization uses `lib/firebase_options*.dart`. Generate per environment:

```bash
flutterfire configure --project <dev-project-id> --out lib/firebase_options_dev.dart
flutterfire configure --project <staging-project-id> --out lib/firebase_options_staging.dart
flutterfire configure --project <prod-project-id> --out lib/firebase_options.dart
```

### Run commands

```bash
# DEV
flutter run --flavor dev -t lib/main_dev.dart

# STAGING
flutter run --flavor staging -t lib/main_staging.dart

# PROD
flutter run --flavor prod -t lib/main.dart
```

### Run on Web (Chrome)

Google Maps on web requires a Maps JS API key:
```bash
# DEV
flutter run -d chrome -t lib/main_dev.dart --dart-define=MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY

# STAGING
flutter run -d chrome -t lib/main_staging.dart --dart-define=MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY

# PROD
flutter run -d chrome -t lib/main.dart --dart-define=MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

### Alternative: Run on specific device
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

## 5. Firebase Setup (Required)

Before the app will work fully, you need to:

1. **Enable Firebase services (for each environment)**:
   - Go to https://console.firebase.google.com/
   - Enable the same services in all 3 projects:
     - `cutline-dev` (dev)
     - `cutline-526aa` (staging)
     - `cutline-prod-a55b9` (prod)
   - Common required services:
     - Authentication (Email/Password)
     - Firestore Database (create the database if it doesn’t exist)
     - Cloud Messaging (if you use FCM)
     - Storage (if you upload images/files)

2. **Configure Firestore Rules**:
   - Recommended (CLI): deploy to each Firebase project:
     ```bash
     firebase deploy --only firestore:rules,firestore:indexes --project dev
     firebase deploy --only firestore:rules,firestore:indexes --project staging
     firebase deploy --only firestore:rules,firestore:indexes --project prod
     ```
   - Alternative (Console): copy rules from `firestore.rules` and publish

3. **Configure Storage Rules**:
   - Go to Storage > Rules in Firebase Console
   - Add the rules from SETUP_INSTRUCTIONS.md

## 6. Test the App

1. Launch app → Splash screen appears
2. Select role (User/Owner/Barber)
3. Sign up or login
4. Test the flows

### Testing as Owner:
1. Sign up as Owner
2. Create salon
3. Add barbers
4. Add services

### Testing as User:
1. Sign up as User
2. Browse salons
3. Select barber
4. Book service
5. Track queue

### Testing as Barber:
1. Sign up as Barber
2. View queue
3. Toggle availability
4. Mark customers as served

## Troubleshooting

### Error: Flutter command not found
**Solution**: Install Flutter or add to PATH
```bash
export PATH="$PATH:/path/to/flutter/bin"
```

### Error: Firebase not initialized
**Solution**: Check Firebase configuration
- Verify `firebase_options.dart` is present
- Check Firebase project settings
- Ensure all services are enabled

### Error: Permission denied
**Solution**: Check Firestore rules
- Ensure rules are deployed
- Check user authentication

### Error: No devices found
**Solution**: Connect device or start emulator
```bash
# Android
flutter emulators --launch <emulator-name>

# iOS
open -a Simulator
```

### Error: Package conflicts
**Solution**: Clean and rebuild
```bash
flutter clean
flutter pub get
flutter run
```

## Development Tips

- **Hot Reload**: Press `r` in terminal
- **Hot Restart**: Press `R` in terminal
- **Quit**: Press `q` in terminal
- **Clear logs**: Press `c` in terminal

## Useful Commands

```bash
# Check Flutter setup
flutter doctor

# List devices
flutter devices

# Run in release mode
flutter run --release

# Build APK (Android)
flutter build apk

# Build IPA (iOS)
flutter build ios

# Analyze code
flutter analyze

# Format code
flutter format lib/

# Run tests
flutter test
```

## Project Status

✅ All core features implemented
✅ Material 3 theme ready
✅ Firebase configured
✅ No compilation errors
✅ Ready to run and test

## Next Steps After Running

1. Test all user flows
2. Verify Firebase integration
3. Test real-time updates
4. Test notifications
5. Customize UI if needed
6. Add more services

---

**Need help?** Check:
- README.md for overview
- SETUP_INSTRUCTIONS.md for detailed setup
- IMPLEMENTATION_SUMMARY.md for features
- FIXES_APPLIED.md for known issues

**Happy coding! 🎉**
