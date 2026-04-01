# CutLine Admin Setup

## Firebase

### Dev admin build

If you want to test against `cutline-dev`, register the Android app with package
name `com.cutline.admin_dev` and place its config at:

`android/app/src/admindev/google-services.json`

Run:

```bash
flutter run --flavor admindev -t lib/admin_main_dev.dart
```

### Prod admin build

1. In the production Firebase project, create a new Android app with package
   name `com.cutline.admin`.
2. Download `google-services.json`.
3. Place it at `android/app/src/admin/google-services.json`.

## Super Admin Claims

Use the functions script with Application Default Credentials or a service
account:

```bash
cd functions
npm run set:superadmin -- --uid <firebase-uid> --enabled true
```

You can also target a user by email:

```bash
cd functions
npm run set:superadmin -- --email admin@example.com --enabled true
```

## Build

```bash
flutter pub get
flutter build apk --flavor admin -t lib/admin_main.dart
```

For Play Internal Testing or direct APK sharing, use the same admin target.
