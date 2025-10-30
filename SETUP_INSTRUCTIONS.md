# 🚀 Cutline Setup Instructions

## Prerequisites

1. **Flutter SDK** - Install from [flutter.dev](https://flutter.dev)
2. **Firebase Project** - Already configured, but you may need to set up additional features
3. **Development Environment**:
   - For Android: Android Studio
   - For iOS: Xcode (macOS only)

## Step-by-Step Setup

### 1. Install Dependencies

```bash
cd /Users/rifat/StudioProjects/cutline
flutter pub get
```

### 2. Firebase Configuration

Your Firebase project is already configured with the following credentials:
- **Project ID**: cutline-526aa
- **Web App ID**: Already set in `lib/firebase_options.dart`
- **Android/iOS Apps**: Already configured

#### Enable Firebase Services

1. **Authentication**
   - Go to Firebase Console > Authentication
   - Enable "Email/Password" sign-in method
   - Add authorized domains if needed

2. **Firestore Database**
   - Go to Firebase Console > Firestore Database
   - Create database in production mode
   - Copy the security rules from `firestore.rules` file

3. **Cloud Messaging (FCM)**
   - Go to Firebase Console > Cloud Messaging
   - This is automatically enabled

4. **Storage**
   - Go to Firebase Console > Storage
   - Create storage bucket
   - Set up rules (see below)

### 3. Firestore Security Rules

Copy the rules from `firestore.rules` to your Firebase Console:
- Go to Firestore Database > Rules
- Replace with the provided rules
- Publish

### 4. Storage Security Rules

Add this to Firebase Console > Storage > Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.resource.size < 5 * 1024 * 1024 // 5MB limit
        && request.resource.contentType.matches('image/.*');
    }
  }
}
```

### 5. Android Configuration

The Android app is already configured with `google-services.json`.

To build and run:
```bash
flutter run
```

### 6. iOS Configuration

The iOS app is already configured with `GoogleService-Info.plist`.

To build and run:
```bash
flutter run
```

### 7. Testing

#### Create Test Accounts

1. **Owner Account**
   - Sign up with role "Owner"
   - Create a salon
   - Add services

2. **Barber Account**
   - Sign up with role "Barber"
   - Owner adds barber to salon
   - Barber can manage their queue

3. **User Account**
   - Sign up with role "User"
   - Browse salons
   - Book appointments

## Common Issues

### Issue: Firebase not initialized

**Solution**: Make sure you've run `flutter pub get` and Firebase is properly configured.

### Issue: Permission denied errors

**Solution**: Check Firestore security rules are properly deployed.

### Issue: Image upload fails

**Solution**: Verify Storage rules and ensure image file size is under 5MB.

### Issue: Notifications not working

**Solution**: 
- Check FCM configuration
- Verify device permissions
- Test with Firebase Console

## Development Tips

1. **Hot Reload**: Use `r` in terminal or Cmd/Ctrl + S in IDE
2. **Clear Build**: `flutter clean && flutter pub get`
3. **Run on Specific Device**: `flutter run -d <device-id>`
4. **Check Logs**: `flutter logs`

## Next Steps

1. Test all user flows
2. Customize UI colors/themes
3. Add more services
4. Implement payments
5. Add analytics

## Support

For issues or questions:
- Check README.md
- Review Firebase documentation
- Check Flutter documentation

---

**Happy Coding! 🎉**
