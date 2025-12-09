# Fix IAM Permissions for Cloud Functions Deployment

## Problem
You're getting this error:
```
Permission "iam.serviceAccounts.ActAs" denied on "EndUserCredentials to 766335706711-compute@developer.gserviceaccount.com"
```

## Solution: Grant Service Account User Role

### Step 1: Open Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project: **cutline-526aa**

### Step 2: Navigate to IAM & Admin
1. Click the hamburger menu (☰) in the top left
2. Go to **IAM & Admin** > **IAM**

### Step 3: Grant Permission
1. Find your user account (the email you're logged in with)
2. Click the **pencil icon** (Edit) next to your account
3. Click **ADD ANOTHER ROLE**
4. Select: **Service Account User** (roles/iam.serviceAccountUser)
5. Click **SAVE**

### Step 4: Retry Deployment
```bash
firebase deploy --only functions
```

## Alternative: Use gcloud CLI

If you have `gcloud` CLI installed:

```bash
# Set your project
gcloud config set project cutline-526aa

# Get your email
MY_EMAIL=$(gcloud config get-value account)

# Grant the role
gcloud projects add-iam-policy-binding cutline-526aa \
  --member="user:${MY_EMAIL}" \
  --role="roles/iam.serviceAccountUser"
```

Then retry:
```bash
firebase deploy --only functions
```

## Why This Happens

Firebase Functions v2 (2nd Gen) requires the deployer to have permission to act as the service account that will run the functions. The default service account is `PROJECT_NUMBER-compute@developer.gserviceaccount.com`.

The "Service Account User" role allows you to impersonate service accounts, which is required for deploying and managing Cloud Functions.

