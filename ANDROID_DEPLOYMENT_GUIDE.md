# Complete Android Play Store Deployment Guide

This guide covers everything you need to deploy your app to Google Play Store.

---

## 📋 Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Create Release Keystore](#2-create-release-keystore)
3. [Configure App Signing](#3-configure-app-signing)
4. [Update Build Configuration](#4-update-build-configuration)
5. [Google Play Console Setup](#5-google-play-console-setup)
6. [Create Subscriptions](#6-create-subscriptions)
7. [RevenueCat Android Setup](#7-revenuecat-android-setup)
8. [Build Android App Bundle (AAB)](#8-build-android-app-bundle-aab)
9. [Upload to Internal Testing](#9-upload-to-internal-testing)
10. [Test Purchases](#10-test-purchases)
11. [Submit for Review](#11-submit-for-review)

---

## 1. Prerequisites

### Required Accounts
- ✅ Google Play Console account ($25 one-time fee)
- ✅ RevenueCat account (already have)
- ✅ Firebase project (already have)

### Required Tools
- ✅ Flutter SDK (already have)
- ✅ Android Studio (optional, but helpful)
- ✅ Java JDK (for creating keystore)

### Check Current Status
```bash
# Check Flutter version
flutter --version

# Check Android setup
flutter doctor
```

---

## 2. Create Release Keystore

**⚠️ IMPORTANT: Keep this keystore safe! You'll need it for all future updates.**

### Step 2.1: Generate Keystore

```bash
cd android/app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**You'll be prompted for:**
- **Keystore password**: Choose a strong password (save it!)
- **Key password**: Can be same as keystore password
- **Name**: Your name or organization
- **Organizational Unit**: (can be blank)
- **Organization**: Your company/org name
- **City**: Your city
- **State**: Your state
- **Country Code**: 2-letter code (e.g., US, NG)

**Example:**
```
Enter keystore password: [YOUR_PASSWORD]
Re-enter new password: [YOUR_PASSWORD]
What is your first and last name?
  [Unknown]:  Your Name
What is the name of your organizational unit?
  [Unknown]:  Development
What is the name of your organization?
  [Unknown]:  Your Company
What is the name of your City or Locality?
  [Unknown]:  Lagos
What is the name of your State or Province?
  [Unknown]:  Lagos
What is the two-letter country code for this unit?
  [Unknown]:  NG
```

### Step 2.2: Create key.properties File

Create `android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

**⚠️ Add to .gitignore:**
```
android/key.properties
android/app/upload-keystore.jks
```

---

## 3. Configure App Signing

Update `android/app/build.gradle.kts` to use the keystore for release builds.

### Step 3.1: Update build.gradle.kts

We'll modify the file to:
1. Load key.properties
2. Configure signing configs
3. Use release signing for release builds

---

## 4. Update Build Configuration

After configuring signing, verify version numbers match `pubspec.yaml`.

---

## 5. Google Play Console Setup

### Step 5.1: Create App

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **"Create app"**
3. Fill in:
   - **App name**: "Get My Car - Find Parked Car"
   - **Default language**: English (United States)
   - **App or game**: App
   - **Free or paid**: Free
   - **Declarations**: Agree to policies
4. Click **"Create app"**

### Step 5.2: Complete App Access Setup

1. **App access**: Select "All features"
2. **Ads**: Select "Yes" if you have ads, "No" if not
3. Click **"Save"**

### Step 5.3: Complete Content Rating

1. **Category**: "All Other App Types"
2. **Email**: Your email
3. **Data collection**: Answer questions
4. **Complete questionnaire**
5. Submit for rating (usually instant)

### Step 5.4: Complete Data Safety

1. **Data collection**: Yes (you collect location)
2. **Data types**: Select:
   - Location (Approximate, Precise)
   - Device IDs
   - App activity
3. **Encryption**: Yes (in transit)
4. **Account creation**: Username and password, OAuth
5. **Data usage**: App functionality, Analytics, Account management
6. **Save and publish**

---

## 6. Create Subscriptions

### Step 6.1: Create Subscription Group

1. Play Console → **Monetize** → **Subscriptions**
2. Click **"Create subscription group"**
3. Name: "Premium Plan"
4. Click **"Create"**

### Step 6.2: Create Monthly Subscription

1. Click **"Create subscription"**
2. **Product ID**: `monthly_sub` (must match iOS)
3. **Name**: "Monthly Subscription"
4. **Description**: "Access all premium features. Auto-renewable monthly."
5. **Billing period**: Monthly
6. **Price**: Set your price
7. **Free trial**: 3 days (or as desired)
8. Click **"Save"**

### Step 6.3: Create Yearly Subscription

1. Click **"Create subscription"** again
2. **Product ID**: `Yearly_sub` (must match iOS)
3. **Name**: "Yearly Subscription"
4. **Description**: "Access all premium features. Auto-renewable yearly."
5. **Billing period**: Yearly
6. **Price**: Set your price
7. **Free trial**: 3 days (or as desired)
8. Click **"Save"**

### Step 6.4: Activate Subscriptions

1. Go to **Monetize** → **Subscriptions**
2. Find each subscription
3. Click **"Activate"** for both

---

## 7. RevenueCat Android Setup

### Step 7.1: Get Google Play Service Account

1. Play Console → **Setup** → **API access**
2. Click **"Link service account"** (if not linked)
3. Click **"Create new service account"**
4. Follow Google Cloud Console steps
5. Download **JSON key file**
6. Save it securely (you'll upload to RevenueCat)

### Step 7.2: Add Service Account to RevenueCat

1. RevenueCat Dashboard → **Project Settings** → **API Keys**
2. Scroll to **"Google Play Service Account"**
3. Click **"Upload service account JSON"**
4. Upload the JSON key file you downloaded
5. Click **"Save"**

### Step 7.3: Get Android API Key

1. RevenueCat Dashboard → **Project Settings** → **API Keys**
2. Find **"Android API Key"** (starts with `goog_`)
3. Copy the API key

### Step 7.4: Update Flutter Code

The code is already set up! Just replace the placeholder in `lib/services/revenuecat_service.dart`:

```dart
static const String rcApiKeyAndroid = 'goog_YOUR_ACTUAL_API_KEY_HERE';
```

Replace with your actual Android API key.

### Step 7.5: Sync Products in RevenueCat

1. RevenueCat Dashboard → **Products**
2. Click **"Sync with Google Play"**
3. Wait for sync (may take a few minutes)
4. Products should appear: `monthly_sub`, `Yearly_sub`

### Step 7.6: Link Products to Entitlement

1. RevenueCat Dashboard → **Entitlements** → `getmycar`
2. Under **"Product IDs"**, click **"+ Attach product"**
3. Select `monthly_sub` → **"Attach"**
4. Select `Yearly_sub` → **"Attach"**

### Step 7.7: Add Products to Offering

1. RevenueCat Dashboard → **Offerings** → `default`
2. Under **"Packages"**, click **"+ Add package"**
3. Add `monthly_sub` as monthly package
4. Add `Yearly_sub` as annual package
5. Click **"Save"**

---

## 8. Build Android App Bundle (AAB)

### Step 8.1: Update Version (if needed)

Check `pubspec.yaml`:
```yaml
version: 2.3.3+4  # Format: version_name+build_number
```

### Step 8.2: Build AAB

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Step 8.3: Find Your AAB

The AAB file will be at:
```
build/app/outputs/bundle/release/app-release.aab
```

---

## 9. Upload to Internal Testing

### Step 9.1: Go to Internal Testing

1. Play Console → **Testing** → **Internal testing**
2. Click **"Create new release"**

### Step 9.2: Upload AAB

1. Click **"Upload"**
2. Select `app-release.aab` from `build/app/outputs/bundle/release/`
3. Wait for processing (5-10 minutes)
4. Add **"Release name"**: e.g., "2.3.3 (4)"
5. Add **"Release notes"**: "Initial release with subscriptions"

### Step 9.3: Add Testers

1. Go to **Testers** tab
2. Click **"Create email list"** (if needed)
3. Add your email address
4. Click **"Save changes"**

### Step 9.4: Start Testing

1. Go back to **"Releases"** tab
2. Click **"Save"** (if not saved automatically)
3. Status should show **"Available to testers"**

---

## 10. Test Purchases

### Step 10.1: Install Test App

1. Install **Google Play Console** app (if on phone)
2. Or get **Internal Testing link** from Play Console
3. Open link on Android device
4. Install app (will show "Internal testing" badge)

### Step 10.2: Test Purchase Flow

1. Open app
2. Tap **"Try for free"**
3. Complete purchase (will be free in testing)
4. Verify subscription activates

### Step 10.3: Test Restore

1. Tap **"Restore"** button
2. Verify subscription restores correctly

---

## 11. Submit for Review

### Step 11.1: Complete Store Listing

1. **App icon**: Upload 512x512px icon
2. **Feature graphic**: 1024x500px image
3. **Screenshots**: Minimum 2 (phone/tablet as needed)
4. **Short description**: Max 80 characters
5. **Full description**: Detailed app description
6. **Privacy policy URL**: Your privacy policy URL

### Step 11.2: Create Production Release

1. Play Console → **Production** → **Releases**
2. Click **"Create new release"**
3. Upload AAB (same as Internal Testing)
4. Add release notes
5. Click **"Save"**

### Step 11.3: Submit for Review

1. Go to **"Production"** → **"Releases"**
2. Click **"Review release"**
3. Review all sections:
   - ✅ Content rating
   - ✅ Data safety
   - ✅ Store listing
   - ✅ Subscriptions
   - ✅ Release details
4. Click **"Start rollout to Production"**

---

## ✅ Checklist

- [ ] Keystore created and secured
- [ ] key.properties configured
- [ ] build.gradle.kts updated with signing
- [ ] Google Play Console app created
- [ ] Content rating completed
- [ ] Data safety completed
- [ ] Subscriptions created (`monthly_sub`, `Yearly_sub`)
- [ ] Subscriptions activated
- [ ] Google Play service account created
- [ ] Service account JSON uploaded to RevenueCat
- [ ] RevenueCat Android API key added to code
- [ ] Products synced in RevenueCat
- [ ] Products linked to entitlement
- [ ] Products added to offering
- [ ] AAB built successfully
- [ ] Uploaded to Internal Testing
- [ ] Testers added
- [ ] Purchases tested successfully
- [ ] Store listing completed
- [ ] Production release created
- [ ] Submitted for review

---

## 🔧 Troubleshooting

### Build Errors
- **"Keystore file not found"**: Check `key.properties` path
- **"Signing config not found"**: Verify `build.gradle.kts` configuration
- **"Version mismatch"**: Check `pubspec.yaml` version matches build

### Purchase Errors
- **"Product not found"**: Verify Product IDs match in Play Console and RevenueCat
- **"Subscription not available"**: Ensure subscriptions are activated
- **"RevenueCat sync failed"**: Check service account JSON is correct

### Upload Errors
- **"AAB validation failed"**: Check version code increments
- **"Signing error"**: Verify keystore and key.properties are correct

---

## 📚 Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [RevenueCat Android Setup](https://www.revenuecat.com/docs/entitlements)

---

**Next Steps**: Follow this guide step by step. We'll help you configure the code files as needed.
