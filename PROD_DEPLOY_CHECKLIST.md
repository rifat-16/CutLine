# Prod Deploy Checklist (CutLine)

## 0) Pre-release

- [ ] Bump `version` in `pubspec.yaml`
- [ ] Confirm release secrets/config files exist:
  - `android/key.properties`
  - `android/local.properties` (contains `MAPS_API_KEY` or `MAPS_API_KEY_PROD`)
  - `ios/Flutter/Secrets.xcconfig` (contains `MAPS_API_KEY`)
  - `android/app/src/prod/google-services.json`
  - `ios/Runner/Firebase/GoogleService-Info-prod.plist`

## 1) Quality gates

```bash
flutter pub get
flutter analyze
flutter test
cd functions
npm ci
npm run lint
cd ..
```

## 2) Build release artifacts

```bash
flutter build appbundle --flavor prod -t lib/main.dart --release
flutter build ipa --flavor prod -t lib/main.dart --release
```

## 3) Deploy production Firebase

```bash
firebase use prod
firebase use
firebase deploy --only firestore:rules,firestore:indexes --project cutline-prod-a55b9
firebase deploy --only functions --project cutline-prod-a55b9
```

## 4) Optional one-time backfill (existing production data)

Dry-run:

```bash
cd functions
node scripts/backfill_owner_salon_id.js --project cutline-prod-a55b9
node scripts/backfill_user_bookings.js --project cutline-prod-a55b9
```

Apply:

```bash
node scripts/backfill_owner_salon_id.js --project cutline-prod-a55b9 --apply
node scripts/backfill_user_bookings.js --project cutline-prod-a55b9 --apply
cd ..
```

## 5) Post-deploy smoke test

- [ ] User login/signup works
- [ ] Owner login/dashboard/queue actions work
- [ ] Barber login/queue updates work
- [ ] User can create/cancel booking
- [ ] Push notifications delivered
- [ ] Map opens correctly on Android and iOS
- [ ] Crashlytics event visible in Firebase console

## 6) Monitoring (first 24h)

- [ ] Check Firebase Functions logs for errors
- [ ] Check Firestore/Functions usage spikes
- [ ] Check Crashlytics for new fatal issues
