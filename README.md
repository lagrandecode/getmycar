# Find My Car - Flutter App

A smart parking assistant app built with Flutter.

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Firebase Configuration

#### Android
1. Download `google-services.json` from Firebase Console
2. Place it in: `android/app/google-services.json`

#### iOS
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it in: `ios/Runner/GoogleService-Info.plist`

### 3. Google Maps Configuration

#### Android
1. Get Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable "Maps SDK for Android"
3. Update `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_API_KEY_HERE" />
   ```

#### iOS
1. Get Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable "Maps SDK for iOS"
3. Add to `ios/Runner/Info.plist`:
   ```xml
   <key>GMSApiKey</key>
   <string>YOUR_API_KEY_HERE</string>
   ```
4. Run `pod install` in `ios/` directory

### 4. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
│   ├── user_model.dart
│   └── parking_session_model.dart
├── services/              # Business logic
│   ├── auth_service.dart
│   ├── location_service.dart
│   ├── parking_service.dart
│   └── ai_service.dart
└── screens/               # UI screens
    ├── login_screen.dart
    ├── home_screen.dart
    ├── save_parking_screen.dart
    ├── navigate_screen.dart
    ├── history_screen.dart
    └── faq_screen.dart
```

## Features

- ✅ User authentication (Firebase Auth)
- ✅ GPS location tracking
- ✅ Save parking spots with photos and notes
- ✅ AI-powered note parsing
- ✅ Natural language search
- ✅ Google Maps integration
- ✅ Parking history

## Troubleshooting

**"Firebase not initialized"**
- Make sure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in place
- Run `flutter clean && flutter pub get`

**"Google Maps not showing"**
- Verify API key is set correctly
- Check API key restrictions in Google Cloud Console
- Ensure Maps SDK is enabled

**"Location permission denied"**
- Check device settings
- For iOS: Verify Info.plist has location usage descriptions
