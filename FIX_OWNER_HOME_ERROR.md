# Fix "Failed to load data" Error on Owner Home Screen

## Problem
Owner home screen shows "Failed to load data. Pull to refresh" error.

## Possible Causes

### 1. Missing Firestore Indexes
The queries might need composite indexes. Check Firebase Console for missing index errors.

### 2. Salon Not Set Up
If the owner hasn't set up their salon yet, the error might appear.

## Solution

### Step 1: Check Firestore Console for Missing Indexes

1. Go to [Firebase Console](https://console.firebase.google.com/project/cutline-526aa/firestore/indexes)
2. Check if there are any "Create Index" links
3. Click to create any missing indexes

### Step 2: Verify Salon Setup

1. Check if salon document exists in Firestore:
   - Go to Firestore Database
   - Check `salons/{ownerId}` document
   - If it doesn't exist, owner needs to complete salon setup

### Step 3: Check Firestore Rules

Make sure the owner can read their own salon data:
- `salons/{salonId}` - owner should be able to read
- `salons/{salonId}/bookings` - owner should be able to read
- `salons/{salonId}/queue` - owner should be able to read

## Code Changes Made

1. **Improved Error Handling**: 
   - Error only shows for real failures, not empty data
   - Salon not existing is handled gracefully
   - Empty queue/bookings don't trigger errors

2. **Better User Experience**:
   - Shows helpful message if salon not set up
   - Error messages are more informative
   - Pull to refresh works properly

## Test

1. **New Owner (No Salon)**:
   - Should show setup prompt, not error
   
2. **Owner with Salon (No Data)**:
   - Should show empty state, not error
   
3. **Owner with Data**:
   - Should load normally without errors

## If Error Persists

Check the console logs for specific Firestore errors:
- Missing index errors
- Permission denied errors
- Network errors

Then create the required indexes or fix the rules accordingly.

