import Flutter
import UIKit
import GoogleMaps
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase is configured in Flutter's main.dart - no need to configure here
    // This prevents the "FirebaseApp.configure() could not find GoogleService-Info.plist" error
    
    // Initialize Google Maps with API key from Info.plist
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String {
      GMSServices.provideAPIKey(apiKey)
      print("✅ Google Maps API key initialized: \(apiKey.prefix(20))...")
    } else {
      print("❌ Google Maps API key not found in Info.plist")
      print("⚠️ Make sure GMSApiKey is set in Info.plist")
    }
    
    // Set up notification delegate for iOS 10.0+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    // DON'T set Firebase Messaging delegate here - Firebase isn't initialized yet!
    // Firebase is initialized in Flutter's main.dart, which runs AFTER this method.
    // The Messaging delegate will be set up after Firebase is initialized.
    // Setting it here causes a crash: "FirebaseCore +[FIRApp configure]"
    
    // Set up method channel for registering remote notifications from Flutter
    // Use safe unwrapping to prevent crashes
    guard let window = window,
          let controller = window.rootViewController as? FlutterViewController else {
      print("⚠️ Window or rootViewController not ready yet - method channel setup skipped")
      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    let notificationChannel = FlutterMethodChannel(
      name: "com.lagrangecode.getmycar/notifications",
      binaryMessenger: controller.binaryMessenger
    )
    
    notificationChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "registerForRemoteNotifications" {
        print("📱 Registering for remote notifications from Flutter...")
        print("📱 Current notification authorization status check...")
        
        // Check if we can register
        if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 Notification authorization status: \(settings.authorizationStatus.rawValue)")
            if settings.authorizationStatus == .authorized {
              print("📱 Authorization is granted, calling registerForRemoteNotifications()")
              DispatchQueue.main.async {
                application.registerForRemoteNotifications()
                result(true)
              }
            } else {
              print("❌ Notification authorization not granted: \(settings.authorizationStatus.rawValue)")
              result(FlutterError(code: "PERMISSION_DENIED", message: "Notification permission not granted", details: nil))
            }
          }
        } else {
          application.registerForRemoteNotifications()
          result(true)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Register Car Bluetooth handler before GeneratedPluginRegistrant
    // Note: Uncomment after adding CarBluetoothHandler.swift to Xcode project
    // CarBluetoothHandler.register(with: registrar(forPlugin: "CarBluetoothHandler"))
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle FCM token refresh
  override func application(_ application: UIApplication, 
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("✅ APNS token received in AppDelegate: \(token.prefix(20))...")
    
    // Only set APNs token if Firebase is initialized
    // Firebase is initialized in Flutter's main.dart, which may not be ready yet
    // So we check if Firebase is available before using Messaging
    if FirebaseApp.app() != nil {
    Messaging.messaging().apnsToken = deviceToken
    } else {
      print("⚠️ Firebase not initialized yet - APNs token will be set later by FCMService")
      // Store token to set later when Firebase is ready
      // FCMService will handle this when it initializes
    }
    
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle FCM token registration failure
  override func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    print("❌ Error details: \(error)")
    
    // Check if it's a capability issue
    if let nsError = error as NSError? {
      print("❌ Error domain: \(nsError.domain)")
      print("❌ Error code: \(nsError.code)")
      print("❌ Error userInfo: \(nsError.userInfo)")
    }
  }
}
