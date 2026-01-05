# Car Bluetooth Implementation Guide

This document describes the Audiomack-style Car Bluetooth feature implementation for the Find My Car app.

## Overview

The feature detects when the user's phone connects/disconnects from a car Bluetooth device and automatically:
- Shows a notification when connected: "Connected - Your phone is now connected to your car."
- Saves parking location when disconnected

## Architecture

### Dart Services

1. **`lib/services/car_bluetooth_service.dart`**
   - Main service for Bluetooth detection
   - Uses platform channels to communicate with native code
   - Uses EventChannel for streaming connection events
   - Implements hybrid detection (heuristic + user-selected device)
   - Stores user-selected device in SharedPreferences

2. **`lib/services/car_location_capture.dart`**
   - Captures GPS location when car disconnects
   - Saves parking session to Firestore
   - Shows parking saved notification

3. **`lib/services/notification_service.dart`**
   - Updated with `showCarConnectedNotificationSimple()` method
   - Shows silent notification on car connection

### Platform Implementations

#### Android (`android/app/src/main/kotlin/com/lagrangecode/getmycar/`)

1. **`CarBluetoothHandler.kt`**
   - Uses Android's Bluetooth Classic APIs
   - Listens for `ACTION_ACL_CONNECTED` and `ACTION_ACL_DISCONNECTED` broadcast intents
   - Uses EventChannel to stream events to Flutter
   - Supports getting paired devices list

2. **`MainActivity.kt`**
   - Initializes CarBluetoothHandler in `configureFlutterEngine()`
   - Disposes handler in `onDestroy()`

**Android Permissions** (already in AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

#### iOS (`ios/Runner/`)

1. **`CarBluetoothHandler.swift`**
   - Uses AVAudioSession route changes (iOS limitation)
   - Monitors audio route changes to/from Bluetooth devices
   - **Limitation**: iOS doesn't allow direct access to Bluetooth Classic connection states
   - Best-effort detection using audio route changes
   - Returns empty list for paired devices (iOS restriction)

2. **`AppDelegate.swift`**
   - Registers CarBluetoothHandler as a Flutter plugin

**iOS Limitations:**
- iOS doesn't allow apps to directly access Bluetooth Classic connection states
- This implementation uses AVAudioSession route changes as a workaround
- Not 100% reliable but is the best available approach
- Cannot get list of paired devices (iOS security restriction)

## Detection Strategy

### 1. User-Selected Device (Primary)
- User can select a specific Bluetooth device in Settings
- Device ID (MAC address) is stored in SharedPreferences
- Only triggers when that specific device connects/disconnects

### 2. Heuristic Detection (Fallback)
- If no device is selected, uses automatic detection
- Matches device names against car-related keywords
- Excludes common headphone/earbud patterns

**Car Patterns:**
- car, auto, bmw, mercedes, toyota, honda, ford, etc.
- sync, uconnect, mmi, hands-free, carkit, etc.

**Excluded Patterns:**
- airpods, beats, sony, bose, headphones, earbuds, etc.

## User Interface

### Settings Screen Integration

Added "Select My Car Bluetooth" option in Settings:
- Navigates to `CarBluetoothSettingsScreen`
- Shows list of paired Bluetooth devices
- Allows user to select/deselect "My Car" device

### Car Bluetooth Settings Screen

**`lib/screens/car_bluetooth_settings_screen.dart`**
- Lists all paired Bluetooth devices
- Shows currently selected device
- Allows clearing selection to use heuristic detection
- Shows connection status (Android only)

## Setup Steps

### 1. Install Dependencies

```bash
cd app
flutter pub get
```

Dependencies added:
- `shared_preferences: ^2.2.2` (for storing selected device)

### 2. Android Setup

No additional setup required. Permissions are already in AndroidManifest.xml.

**Note**: For Android 12+ (API 31+), ensure Bluetooth permissions are granted at runtime.

### 3. iOS Setup

No additional setup required. Audio session permissions are handled automatically.

**Note**: The iOS implementation has limitations due to iOS security restrictions.

## Initialization

The service is initialized in `main.dart`:

```dart
// Initialize Car Bluetooth service
await CarBluetoothService.instance.initialize();
await _setupCarBluetoothListener();
await CarBluetoothService.instance.startMonitoring();
```

The listener setup connects the connection stream to notification and location capture logic.

## Testing

### Android Testing

1. Pair your car Bluetooth device with your phone
2. Open app Settings → "Select My Car Bluetooth"
3. Select your car device (or leave unselected for heuristic detection)
4. Connect/disconnect from car Bluetooth
5. Check for notifications and parking location saves

### iOS Testing

1. Pair your car Bluetooth device with your phone
2. Open app Settings → "Select My Car Bluetooth"
3. Note: iOS won't show paired devices (limitation)
4. Connect/disconnect from car Bluetooth
5. Check for notifications (may be less reliable due to iOS limitations)

## Background Behavior

### Android

- Works when app is in foreground
- For background support, consider implementing a foreground service (requires persistent notification)
- Current implementation focuses on foreground detection

### iOS

- Works when app is in foreground
- Background detection is severely limited by iOS
- Audio route changes may work in background if audio session is active
- Full background support would require special entitlements from Apple (typically denied)

## Troubleshooting

### Android Issues

**No events received:**
- Check Bluetooth permissions are granted
- Verify device is paired
- Check logcat for error messages

**Device not detected:**
- Ensure device is actually connected (not just paired)
- Check device name matches car patterns (if using heuristic)
- Try selecting device manually in settings

### iOS Issues

**No events received:**
- iOS limitations may prevent reliable detection
- Ensure audio session is active
- Check Xcode console for error messages

**Device list empty:**
- This is expected - iOS doesn't allow listing paired devices

## Future Improvements

1. **Android**: Implement BluetoothProfile service for more reliable connection state detection
2. **iOS**: Explore Core Bluetooth (BLE) for better detection (limited to BLE devices)
3. **Background**: Implement foreground service for Android background detection
4. **User Experience**: Add visual indicators in UI when car is connected
5. **Settings**: Allow custom pattern configuration for heuristic detection

