# Firebase Storage CORS Configuration for Web

## Problem
Images from Firebase Storage are not loading on Flutter web due to CORS (Cross-Origin Resource Sharing) restrictions.

**Error you're seeing:**
```
EncodingError: The source image cannot be decoded.
```

This happens because the browser blocks the image request due to missing CORS headers from Firebase Storage.

## Solution: Configure CORS for Firebase Storage

### Step 1: Access Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Make sure you're logged in with the account associated with your Firebase project
3. Select your project: **cutline-526aa**

### Step 2: Open Cloud Shell
1. Click the "Activate Cloud Shell" icon (terminal icon) in the top-right corner
2. This opens a terminal at the bottom of the page

### Step 3: Set Active Project
Run this command in Cloud Shell:
```bash
gcloud config set project cutline-526aa
```

### Step 4: Apply CORS Configuration
Run this command to apply CORS settings to your Firebase Storage bucket:
```bash
gsutil cors set cors.json gs://cutline-526aa.firebasestorage.app
```

**Note:** The `cors.json` file is already created in your project root with the correct configuration.

### Step 5: Verify Configuration
To confirm CORS settings were applied:
```bash
gsutil cors get gs://cutline-526aa.firebasestorage.app
```

You should see output like:
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type", "Access-Control-Allow-Origin"],
    "maxAgeSeconds": 3600
  }
]
```

### Alternative: Using Firebase Console
If you prefer using the Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **cutline-526aa**
3. Go to Storage
4. Click on the Settings/Configuration tab
5. Look for CORS settings (may require using gcloud CLI)

## For Production
For better security, replace `"origin": ["*"]` in `cors.json` with your specific domain:
```json
[
  {
    "origin": ["https://yourdomain.com", "https://www.yourdomain.com"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type", "Access-Control-Allow-Origin"],
    "maxAgeSeconds": 3600
  }
]
```

## Testing Locally
If testing on `localhost`, you can temporarily add it to the origin array:
```json
{
  "origin": ["*", "http://localhost:*"],
  ...
}
```

## After Configuration
1. Restart your Flutter web app
2. Clear browser cache (Ctrl+Shift+Delete or Cmd+Shift+Delete)
3. Images should now load correctly on web

## Troubleshooting
- If images still don't load, check browser console (F12) for CORS errors
- Verify the bucket name matches: `cutline-526aa.firebasestorage.app`
- Make sure you have proper permissions to modify Storage settings
- Check that image URLs are correct in Firestore database
