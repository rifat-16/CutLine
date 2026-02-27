# ✂️ CutLine

**Skip the waiting line — your haircut, your time.**

A smart salon queue management app with multi-barber support, real-time tracking, and FCM notifications. Built with Flutter and Firebase.

## 🎯 Features

### 👤 User Features
- Browse available salons with search functionality
- View salon details, barbers, services, and gallery
- Book appointments with specific barbers
- Real-time queue tracking and position updates
- FCM push notifications when turn is near
- Manage favorite salons
- View booking history and receipts
- Chat with salon owners
- Edit profile and manage account

### 💈 Owner Features
- Create and manage salon profile
- Add multiple barbers with individual profiles
- Set services and pricing (including combo deals)
- Manage salon gallery (up to 10 photos)
- Set working hours
- View comprehensive dashboard with analytics
- Manage booking requests and confirmations
- View all bookings and receipts
- Manage queue across all barbers
- Real-time notifications
- Chat with customers
- Contact support

### 🧔 Barber Features
- Manage own private queue view
- Mark customers as served or skipped
- Toggle availability status
- Real-time queue updates
- View work history
- Edit profile
- Receive notifications

## 🏗️ Architecture

### Tech Stack
- **Flutter** - Cross-platform framework (SDK >=3.0.0)
- **Firebase** - Complete backend solution
  - **Authentication** - Email/Password authentication
  - **Cloud Firestore** - Real-time NoSQL database
  - **Cloud Messaging (FCM)** - Push notifications
  - **Storage** - Image uploads and gallery management
  - **Analytics** - User behavior tracking
- **Provider** - State management
- **Flutter ScreenUtil** - Responsive design
- **Google Fonts** - Typography
- **Cached Network Image** - Image caching
- **Flutter Local Notifications** - Local notification support

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
│
├── features/                    # Feature-based architecture
│   ├── auth/                   # Authentication feature
│   │   ├── models/            # User models and roles
│   │   ├── providers/         # Auth state management
│   │   ├── screens/           # Login, signup, role selection
│   │   └── services/          # Auth and profile services
│   │
│   ├── user/                   # User feature
│   │   ├── providers/         # User state management
│   │   ├── screens/           # User screens (home, booking, etc.)
│   │   └── widgets/           # User-specific widgets
│   │
│   ├── owner/                  # Owner feature
│   │   ├── providers/         # Owner state management
│   │   ├── screens/           # Owner screens (dashboard, etc.)
│   │   ├── services/          # Owner business logic
│   │   ├── widgets/           # Owner-specific widgets
│   │   └── utils/             # Owner utilities
│   │
│   └── barber/                 # Barber feature
│       ├── providers/         # Barber state management
│       └── screens/           # Barber screens
│
├── shared/                      # Shared resources
│   ├── models/                # Shared data models
│   ├── services/              # Shared services (notifications, FCM)
│   └── theme/                 # App-wide theming
│
└── routes/                      # Navigation
    └── app_router.dart         # Route definitions and navigation
```

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (>=3.0.0) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Firebase Account** - [Firebase Console](https://console.firebase.google.com/)
- **Development Environment**:
  - Android: Android Studio with Android SDK
  - iOS: Xcode (macOS only)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd CutLine
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**

   The project is pre-configured with Firebase credentials in `lib/firebase_options.dart`.

   **Enable Firebase Services:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select the project for your target flavor (dev/staging/prod)
   - Enable the following services:
     - **Authentication** → Enable Email/Password sign-in method
     - **Firestore Database** → Create database in production mode
     - **Cloud Messaging** → Automatically enabled
     - **Storage** → Create storage bucket
     - **Analytics** → Automatically enabled

4. **Configure Firestore Security Rules**

   Copy the rules from `firestore.rules` to Firebase Console:
   - Go to Firestore Database → Rules
   - Paste the rules and publish

5. **Configure Storage Security Rules**

   Add to Firebase Console → Storage → Rules:
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

6. **Run the app**
   ```bash
   flutter run
   ```

For detailed setup instructions, see [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)

For running instructions, see [RUN_INSTRUCTIONS.md](RUN_INSTRUCTIONS.md)

## 🏁 Production Release Runbook

### Environment mapping (flavor -> Firebase project)

- `dev` -> `cutline-dev`
- `staging` -> `cutline-526aa`
- `prod` -> `cutline-prod-a55b9`

### Required local config before release

- Android Firebase config: `android/app/src/prod/google-services.json`
- iOS Firebase config: `ios/Runner/Firebase/GoogleService-Info-prod.plist`
- Android signing: `android/key.properties`
- Android Maps key: `android/local.properties` (`MAPS_API_KEY` or `MAPS_API_KEY_PROD`)
- iOS Maps key: `ios/Flutter/Secrets.xcconfig` (`MAPS_API_KEY`)

Never commit secret values to git.

### Release preparation

1. Bump app version in `pubspec.yaml` (`version: x.y.z+buildNumber`).
2. Run quality gates:

```bash
flutter pub get
flutter analyze
flutter test
cd functions
npm ci
npm run lint
cd ..
```

### Build production artifacts

```bash
flutter build appbundle --flavor prod -t lib/main.dart --release
flutter build ipa --flavor prod -t lib/main.dart --release
```

Android output: `build/app/outputs/bundle/prodRelease/*.aab`

### Deploy production backend

```bash
firebase use prod
firebase use
firebase deploy --only firestore:rules,firestore:indexes --project cutline-prod-a55b9
firebase deploy --only functions --project cutline-prod-a55b9
```

### Optional one-time backfill (for existing production data)

Run dry-run first, then `--apply`:

```bash
cd functions
node scripts/backfill_owner_salon_id.js --project cutline-prod-a55b9
node scripts/backfill_user_bookings.js --project cutline-prod-a55b9
node scripts/backfill_owner_salon_id.js --project cutline-prod-a55b9 --apply
node scripts/backfill_user_bookings.js --project cutline-prod-a55b9 --apply
cd ..
```

### Post-deploy smoke test

- Login/signup works for user, owner, barber.
- User booking create/cancel works.
- Owner queue actions and dashboard work.
- Barber queue update works.
- Push notifications are received for booking flow.
- Map screen loads on Android and iOS.
- Crashlytics test event appears in Firebase Console.

## 📱 User Flows

### User Journey
1. Launch app → Splash screen
2. Role Selection → Choose "User"
3. Sign up/Login
4. Browse salons (search, filter, view favorites)
5. Select salon → View details, barbers, services, gallery
6. Select barber → Choose service(s)
7. Book appointment → Confirm booking
8. Track queue in real-time
9. Receive notifications when turn is near
10. View booking receipt

### Owner Journey
1. Launch app → Splash screen
2. Role Selection → Choose "Owner"
3. Sign up as Owner
4. Create salon profile
5. Add services and pricing
6. Add barbers
7. Set working hours
8. Upload gallery photos
9. Manage bookings and queue
10. View dashboard analytics
11. Chat with customers

### Barber Journey
1. Launch app → Splash screen
2. Role Selection → Choose "Barber"
3. Login (credentials provided by owner)
4. View own queue
5. Toggle availability
6. Mark customers as served/skipped
7. View work history
8. Manage profile

## 🔒 Security

- **Firebase Authentication** - Secure user authentication
- **Firestore Security Rules** - Role-based access control
- **Storage Rules** - Secure file uploads
- **Barber Queue Isolation** - Barbers can only see their own queue
- **Owner Full Access** - Owners can manage all salon data

## 🔔 Notifications

- **FCM Push Notifications** - Real-time push notifications
- **Local Notifications** - Foreground notification support
- **Queue Position Alerts** - Notify users when their turn approaches
- **Booking Confirmations** - Notify owners of new bookings
- **Service Completion** - Notify users when service is complete

## 📝 Data Model

### Firestore Collections

```
users/{userId}
  - name, phone, email, role, salonId, fcmToken, createdAt

salons/{salonId}
  - name, ownerId, location, address, phone, description
  - services: [service objects]
  - workingHours: {day: {open, close}}
  - gallery: [photo URLs]
  - barbers/{barberId}
    - name, phone, email, available, services
    - queue/{queueId}
      - userId, userName, service, status, timestamp, position

bookings/{bookingId}
  - userId, salonId, barberId, services, date, time
  - status, createdAt, customerInfo
```

## 🎨 Design

- **Color Scheme**: White background with blue primary (#3B82F6) and orange accent (#F97316)
- **Typography**: Google Fonts (sans-serif)
- **Icons**: Material Design Icons
- **Layout**: Card-based design with rounded corners (16px) and soft shadows
- **Responsive**: Mobile-first design with Flutter ScreenUtil
- **Theme**: Material Design 3

## 📦 Dependencies

### Core
- `flutter` - Flutter SDK
- `provider` - State management
- `firebase_core` - Firebase initialization
- `firebase_auth` - Authentication
- `cloud_firestore` - Database
- `firebase_messaging` - Push notifications
- `firebase_storage` - File storage
- `firebase_analytics` - Analytics

### UI & Utilities
- `google_fonts` - Typography
- `flutter_screenutil` - Responsive design
- `cached_network_image` - Image caching
- `shimmer` - Loading animations
- `flutter_animate` - Animations
- `intl` - Internationalization

### Notifications
- `flutter_local_notifications` - Local notifications

### Other
- `image_picker` - Image selection
- `uuid` - Unique ID generation

## 🛠️ Development

### Useful Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run on specific device
flutter run -d <device-id>

# Build APK (Android)
flutter build apk --release

# Build AAB (Play Store)
flutter build appbundle --release

# Build iOS
flutter build ios

# Analyze code
flutter analyze

# Format code
flutter format lib/

# Run tests
flutter test

# Clean build
flutter clean && flutter pub get
```

### Hot Reload
- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

## 🐛 Troubleshooting

### Common Issues

**Firebase not initialized**
- Ensure `firebase_options.dart` is present
- Verify Firebase services are enabled in console
- Run `flutter pub get`

**Permission denied errors**
- Check Firestore security rules are deployed
- Verify user is authenticated
- Check Storage rules

**Image upload fails**
- Verify Storage rules are configured
- Ensure image size is under 5MB
- Check file format (images only)

**Notifications not working**
- Check FCM configuration
- Verify device permissions
- Test with Firebase Console

**No devices found**
- Connect physical device or start emulator
- For Android: `flutter emulators --launch <emulator-name>`
- For iOS: `open -a Simulator`

## 📚 Additional Documentation

- [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) - Detailed setup guide
- [RUN_INSTRUCTIONS.md](RUN_INSTRUCTIONS.md) - How to run the app
- [PROD_DEPLOY_CHECKLIST.md](PROD_DEPLOY_CHECKLIST.md) - Production release checklist
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Feature implementation details
- [FCM_IMPLEMENTATION_SUMMARY.md](FCM_IMPLEMENTATION_SUMMARY.md) - Notification setup
- [firestore.rules](firestore.rules) - Security rules

## 🚧 Future Enhancements

- [ ] Payment integration
- [ ] Reviews and ratings system
- [ ] Loyalty points program
- [ ] Advanced calendar view
- [ ] Multi-language support
- [ ] Dark mode
- [ ] Advanced analytics dashboard
- [ ] In-app video calls
- [ ] Social media integration

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 👥 Team

Built with ❤️ for better salon management

---

**Made with Flutter 💙**

For questions or support, please open an issue on GitHub.
