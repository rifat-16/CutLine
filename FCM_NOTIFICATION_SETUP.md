# FCM Notification System Setup Guide

This guide explains how to set up and deploy the FCM notification system for CutLine.

## Overview

The notification system consists of:
1. **Cloud Functions** - Trigger notifications on booking events
2. **Flutter Services** - Handle notifications in the app (foreground, background, terminated)
3. **Token Management** - Save and update FCM tokens in Firestore

## Cloud Functions Setup

### Prerequisites

1. Install Node.js (v18 or higher)
2. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
3. Login to Firebase:
   ```bash
   firebase login
   ```

### Deploy Functions

1. Navigate to the functions directory:
   ```bash
   cd functions
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Deploy functions:
   ```bash
   firebase deploy --only functions
   ```

   Or deploy specific functions:
   ```bash
   firebase deploy --only functions:onBookingCreate
   firebase deploy --only functions:onBookingUpdate
   ```

### Functions Overview

- **onBookingCreate**: Triggered when a new booking is created in `salons/{salonId}/bookings/{bookingId}`. Sends notification to salon owner.

- **onBookingUpdate**: Triggered when booking status changes from "upcoming" to "waiting". Sends notifications to:
  - User (customer) - "booking_accepted"
  - Barber - "barber_waiting"

## Flutter App Setup

### Dependencies

The following packages are already included in `pubspec.yaml`:
- `firebase_messaging: ^15.0.0`
- `flutter_local_notifications: ^17.0.0`

### Android Configuration

1. **AndroidManifest.xml** - Already updated with required permissions:
   - `INTERNET`
   - `POST_NOTIFICATIONS`

2. **Google Services** - `google-services.json` is already configured.

### iOS Configuration

1. **Capabilities** - Enable Push Notifications in Xcode:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner target
   - Go to Signing & Capabilities
   - Add "Push Notifications" capability

2. **APNs Certificate** - Upload APNs certificate to Firebase Console:
   - Go to Firebase Console > Project Settings > Cloud Messaging
   - Upload your APNs Authentication Key or Certificate

### Initialization

The notification service is automatically initialized in `main.dart`. The system:
- Requests notification permissions
- Sets up background message handler
- Handles foreground, background, and terminated states
- Saves FCM tokens on user login

## Token Management

### How It Works

1. **On Login**: FCM token is automatically saved to `users/{userId}` document with field `fcmTokens` (array).

2. **Token Refresh**: The app listens for token refresh and automatically updates Firestore.

3. **Multiple Devices**: Users can have multiple tokens (one per device).

4. **Invalid Token Cleanup**: Cloud Functions automatically remove invalid tokens when sending fails.

### Firestore Structure

```javascript
users/{userId}
  - fcmTokens: ["token1", "token2", ...]  // Array of FCM tokens
  - fcmToken: "token1"  // Single token for backward compatibility
```

## Notification Types

### 1. Booking Request (Owner)
- **Trigger**: New booking created with status "upcoming"
- **Type**: `booking_request`
- **Payload**:
  ```json
  {
    "type": "booking_request",
    "bookingId": "<id>",
    "salonId": "<id>",
    "customerName": "<name>"
  }
  ```
- **Navigation**: Opens booking requests screen

### 2. Booking Accepted (User)
- **Trigger**: Booking status changes from "upcoming" to "waiting"
- **Type**: `booking_accepted`
- **Payload**:
  ```json
  {
    "type": "booking_accepted",
    "bookingId": "<id>",
    "salonId": "<id>"
  }
  ```
- **Navigation**: Opens booking receipt/details screen

### 3. Barber Waiting (Barber)
- **Trigger**: Booking status changes from "upcoming" to "waiting"
- **Type**: `barber_waiting`
- **Payload**:
  ```json
  {
    "type": "barber_waiting",
    "bookingId": "<id>",
    "salonId": "<id>"
  }
  ```
- **Navigation**: Opens barber home (queue screen)

## Testing

### Test Cloud Functions Locally

1. Start Firebase emulators:
   ```bash
   firebase emulators:start
   ```

2. Test function triggers by creating/updating bookings in Firestore.

### Test Flutter App

1. **Foreground**: Keep app open and create a booking. You should see a local notification.

2. **Background**: Put app in background, create a booking. You should receive a push notification.

3. **Terminated**: Close the app completely, create a booking. Tap the notification to open the app.

## Troubleshooting

### Notifications Not Received

1. **Check FCM Token**: Verify token is saved in Firestore `users/{userId}/fcmTokens`
2. **Check Permissions**: Ensure notification permissions are granted
3. **Check Cloud Functions Logs**: 
   ```bash
   firebase functions:log
   ```
4. **Check Device Token**: Verify device is registered with FCM

### Cloud Functions Errors

1. Check function logs in Firebase Console
2. Verify Firestore security rules allow function access
3. Ensure Admin SDK is properly initialized

### Android Issues

1. Ensure `google-services.json` is in `android/app/`
2. Check that `POST_NOTIFICATIONS` permission is granted (Android 13+)
3. Verify notification channel is created

### iOS Issues

1. Ensure APNs certificate is uploaded to Firebase
2. Check that Push Notifications capability is enabled
3. Verify `GoogleService-Info.plist` is in `ios/Runner/`

## Security Considerations

1. **Firestore Rules**: Ensure users can only read/write their own FCM tokens
2. **Token Validation**: Cloud Functions validate tokens before sending
3. **Invalid Token Cleanup**: Automatically removes invalid tokens

## Production Checklist

- [ ] Deploy Cloud Functions to production
- [ ] Test notifications on Android device
- [ ] Test notifications on iOS device
- [ ] Verify token saving on login
- [ ] Test all three notification types
- [ ] Test foreground, background, and terminated states
- [ ] Verify navigation works correctly
- [ ] Check Cloud Functions logs for errors
- [ ] Monitor Firestore for token updates

## Support

For issues or questions, check:
- Firebase Console > Functions > Logs
- Flutter app console logs
- Firestore data structure

