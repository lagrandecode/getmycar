import Flutter
import UIKit
import GoogleMaps
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
    
    // Set up Firebase Messaging delegate
    Messaging.messaging().delegate = self
    
    // Set up method channel for registering remote notifications from Flutter
    let controller = window?.rootViewController as! FlutterViewController
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
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle FCM token refresh
  override func application(_ application: UIApplication, 
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("✅ APNS token received in AppDelegate: \(token.prefix(20))...")
    Messaging.messaging().apnsToken = deviceToken
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
