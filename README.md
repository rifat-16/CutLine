# ✂️ Cutline

**Skip the waiting line — your haircut, your time.**

A smart salon queue management app with multi-barber support, real-time tracking, and FCM notifications.

## 🎯 Features

### 👤 User Features
- Browse available salons
- Book slots with specific barbers
- Real-time queue tracking
- Get notifications when your turn is near
- Cancel bookings

### 💈 Owner Features
- Create and manage your salon
- Add multiple barbers
- Set services and pricing
- View overall queue status
- Manage barber availability

### 🧔 Barber Features
- Manage your own queue (private view)
- Mark customers as served or skipped
- Toggle availability status
- Real-time queue updates

## 🏗️ Architecture

- **Flutter** - Cross-platform framework
- **Firebase** - Backend services
  - Authentication (Email/Password)
  - Firestore - Real-time database
  - Cloud Messaging - Push notifications
  - Storage - Image uploads
- **Provider** - State management
- **Real-time Streams** - Live queue updates

## 📁 Project Structure

```
lib/
 ├── main.dart
 ├── firebase_options.dart
 ├── models/          # Data models
 ├── providers/       # State management
 ├── services/        # Business logic
 ├── screens/         # UI screens
 ├── widgets/         # Reusable widgets
 ├── theme/          # App styling
 ├── utils/          # Helpers & constants
 └── routes/         # Navigation
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Firebase account
- Android Studio / Xcode (for mobile)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cutline
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**

   The project is already configured with Firebase credentials in `lib/firebase_options.dart`.

   Set up Firestore security rules:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
       
       match /salons/{salonId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null 
           && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'owner';
         
         match /barbers/{barberId} {
           allow read: if request.auth != null;
           allow write: if request.auth != null 
             && (request.auth.uid == barberId 
               || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'owner');
           
           match /queue/{queueId} {
             allow read, write: if request.auth != null;
           }
         }
       }
       
       match /bookings/{bookingId} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 🎨 Design

- **Colors**: White background with blue primary and orange accents
- **Font**: Sans-serif, Google Fonts
- **Icons**: Material Design
- **Layout**: Card-based, rounded corners, soft shadows

## 📱 User Flows

### User Journey
1. Launch app → Role Selection
2. Sign up/Login
3. Browse salons
4. Select barber
5. Book service
6. Track queue in real-time
7. Get notified when served

### Owner Journey
1. Launch app → Role Selection
2. Sign up as Owner
3. Create salon
4. Add barbers
5. Manage queues
6. View analytics

### Barber Journey
1. Launch app → Role Selection
2. Sign up/Login as Barber
3. Toggle availability
4. Manage own queue
5. Mark customers as served

## 🔒 Security

- Firebase Authentication
- Firestore security rules
- Role-based access control
- Barber queue isolation (can only see own queue)
- Owner full access

## 🔔 Notifications

- FCM for real-time push notifications
- Local notifications for foreground updates
- Queue position alerts
- Service completion notifications

## 📝 Data Model

- **users**: User profiles with roles
- **salons**: Salon information
- **salons/{salonId}/barbers**: Barber details
- **salons/{salonId}/barbers/{barberId}/queue**: Real-time queues
- **bookings**: Customer bookings

## 🛠️ Future Enhancements

- [ ] Payment integration
- [ ] Reviews and ratings
- [ ] Loyalty points system
- [ ] Appointments calendar
- [ ] Multi-language support
- [ ] Analytics dashboard

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 👥 Team

Built with ❤️ for better salon management

---

**Made with Flutter 💙**