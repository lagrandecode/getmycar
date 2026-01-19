# Google Play Console API Access Guide

## Finding API Access

### Method 1: Through Settings
1. Open [Google Play Console](https://play.google.com/console)
2. Click **"Settings"** in the left sidebar (gear icon)
3. Click **"API access"** under Settings
4. You should see service accounts section

### Method 2: Through Setup (if available)
1. Open Google Play Console
2. Look for **"Setup"** in the left sidebar
3. Click **"API access"** under Setup

### Method 3: Direct URL
Go directly to: https://play.google.com/console/developers/api-access

---

## Prerequisites

Before you can create a service account, you need:

1. ✅ **Google Play Developer Account** - You have this ($25 paid)
2. ✅ **App created** - App must be created in Play Console first
3. ❓ **Payment profile** - Must be completed (you're doing this now)

---

## If You Don't See API Access

### Reason 1: Payment Profile Not Complete
- **Fix**: Complete the payments profile form first
- **Then**: API access should appear

### Reason 2: App Not Created
- **Fix**: Create your app in Play Console first
- **Path**: Play Console → "Create app"

### Reason 3: UI Location Different
- **Try**: Settings → Developer account → API access
- **Or**: Account → API access

---

## Step-by-Step After You Find API Access

Once you find API access:

### Step 1: Create Service Account
1. Click **"Create service account"** or **"Link service account"**
2. This opens Google Cloud Console in a new tab

### Step 2: In Google Cloud Console
1. Click **"Create Service Account"**
2. Enter name: `RevenueCat` or `Play Console Service Account`
3. Click **"Create and Continue"**
4. Skip "Grant this service account access to project" (optional)
5. Click **"Done"**

### Step 3: Grant Access in Play Console
1. Go back to Play Console API access tab
2. You should see your service account listed
3. Click **"Grant access"** next to your service account
4. Select permissions: **"View financial data"** and **"View app information and download bulk reports"**
5. Click **"Invite user"**

### Step 4: Create and Download JSON Key
1. Go back to Google Cloud Console
2. Find your service account (IAM & Admin → Service Accounts)
3. Click on the service account name
4. Go to **"Keys"** tab
5. Click **"Add Key"** → **"Create new key"**
6. Select **"JSON"** format
7. Click **"Create"** - JSON file downloads automatically
8. **Save this file securely** - you'll upload it to RevenueCat

### Step 5: Upload to RevenueCat
1. Go back to RevenueCat → Project Settings → API Keys
2. Scroll to **"Google Play Service Account"**
3. Upload the JSON file you downloaded
4. Click **"Save"**

---

## Troubleshooting

### "I don't see API access"
- Complete payment profile first
- Make sure you've created an app in Play Console
- Try the direct URL: https://play.google.com/console/developers/api-access

### "Create service account button not working"
- Make sure your payment profile is complete
- Try refreshing the page
- Check if you have proper permissions on your Play Console account

### "JSON key download fails"
- Try a different browser
- Check Google Cloud Console permissions
- Make sure you're logged into the correct Google account

---

## What You Need NOW vs LATER

### NOW (Before creating service account):
- ✅ Complete payment profile (you're doing this)
- ✅ Create app in Play Console (if not done)
- ❌ Service account JSON (can wait)

### LATER (After service account created):
- Upload JSON to RevenueCat
- Sync products
- Test purchases

---

**For now**: Complete the payment profile, then look for API access again.
