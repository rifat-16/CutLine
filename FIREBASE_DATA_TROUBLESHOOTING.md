# Firebase Data না আসার সমস্যা সমাধান (Firebase Data Troubleshooting)

Owner dashboard এ Firebase থেকে data আসছে না এমন সমস্যা হলে এই steps follow করুন:

## 1. Firestore Rules Deploy করুন

Firestore security rules deploy করতে:

```bash
# Firebase CLI install করুন (যদি না থাকে)
npm install -g firebase-tools

# Firebase এ login করুন
firebase login

# Project select করুন
firebase use cutline-526aa

# Rules deploy করুন
firebase deploy --only firestore:rules
```

**অথবা** Firebase Console থেকে:
1. https://console.firebase.google.com/ → আপনার project select করুন
2. Firestore Database → Rules tab
3. `firestore.rules` file এর content copy করে paste করুন
4. "Publish" button click করুন

## 2. User Document Verify করুন

Owner এর `users/{userId}` document Firebase Console এ check করুন:
- Document ID: Owner এর UID (Firebase Auth থেকে)
- Fields থাকতে হবে:
  - `role`: `"owner"` (string)
  - `email`: Owner এর email
  - `name`: Owner এর নাম
  - `uid`: Owner এর UID

**যদি document না থাকে:**
- Owner কে sign up করে আবার login করতে হবে
- বা manually Firebase Console থেকে create করতে হবে

## 3. Salon Document Check করুন

Owner এর `salons/{ownerId}` document check করুন:
- Document ID: Owner এর UID
- যদি document না থাকে, owner কে salon profile create করতে হবে
- Owner home screen এ "Setup your salon" message দেখাবে যদি salon document না থাকে

## 4. Authentication Verify করুন

Owner সঠিকভাবে authenticated আছে কিনা check করুন:
- App এ login করা আছে
- Firebase Auth এ user active আছে
- User এর UID null না

## 5. Network Connection Check করুন

- Internet connection আছে কিনা verify করুন
- Firebase services accessible আছে কিনা check করুন

## 6. Error Messages Check করুন

App run করার সময় console logs check করুন:
- `flutter run` command terminal এ দেখুন
- `debugPrint` messages check করুন:
  - `fetchAll: Starting for ownerId: ...`
  - `_loadSalon: Attempting to read salons/...`
  - `_loadQueue: Attempting to load queue for ownerId: ...`
  - Permission denied errors থাকলে Firestore rules check করুন

## 7. Common Issues

### Issue: "Permission denied"
**Solution:**
- Firestore rules deploy করুন (Step 1)
- User document এ `role: "owner"` আছে কিনা verify করুন

### Issue: "User document does not exist"
**Solution:**
- Owner কে sign up করে আবার login করতে হবে
- বা Firebase Console থেকে manually create করুন:
```json
{
  "uid": "OWNER_UID",
  "email": "owner@example.com",
  "name": "Owner Name",
  "role": "owner",
  "profileComplete": false,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Issue: "Salon document does not exist"
**Solution:**
- এটা normal - নতুন owner এর salon document তৈরি হওয়া পর্যন্ত
- Owner কে salon profile setup করতে হবে
- Owner home screen এ setup prompt দেখাবে

### Issue: "Firestore index required"
**Solution:**
- Firebase Console → Firestore Database → Indexes
- `firestore.indexes.json` file deploy করুন:
```bash
firebase deploy --only firestore:indexes
```

## 8. Debug Mode

App run করার সময় verbose logs enable করুন:
- Terminal এ `flutter run -v` command use করুন
- সব Firebase operations এর logs দেখবেন

## 9. Firebase Console Debugging

Firebase Console → Firestore Database → Data tab এ:
1. `users/{ownerId}` document check করুন
2. `salons/{ownerId}` document check করুন
3. `salons/{ownerId}/queue` collection check করুন
4. `salons/{ownerId}/bookings` collection check করুন

## 10. Test Firestore Rules

Firebase Console → Firestore Database → Rules tab → Rules Playground:
- Owner UID use করে test করুন
- Read operations test করুন:
  - `salons/{ownerId}`
  - `salons/{ownerId}/queue/{queueId}`
  - `salons/{ownerId}/bookings/{bookingId}`

## Quick Fix Checklist

- [ ] Firestore rules deployed
- [ ] User document exists with `role: "owner"`
- [ ] Owner is authenticated
- [ ] Network connection is working
- [ ] Check console logs for specific errors
- [ ] Firestore indexes created (if needed)
- [ ] Salon document exists (or setup prompt shown)

## Contact/Support

যদি সমস্যা continue করে:
1. Console logs screenshot নিন
2. Firebase Console screenshots নিন
3. Error messages note করুন
4. Debug steps follow করুন








