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
cd /Users/rifat/StudioProjects/cutline
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
flutter run
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

1. **Enable Firebase services**:
   - Go to https://console.firebase.google.com/
   - Select your project "cutline-526aa"
   - Enable Authentication > Email/Password
   - Enable Firestore Database
   - Enable Cloud Messaging
   - Enable Storage

2. **Configure Firestore Rules**:
   - Copy rules from `firestore.rules`
   - Go to Firestore > Rules in Firebase Console
   - Paste and publish

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
