import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you use other Firebase services here, you must call Firebase.initializeApp()
  // in background isolate. (Only needed if you do more than print logs.)
  print('📨 Background message: ${message.messageId}');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
  print('   Data: ${message.data}');
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static String? _fcmToken;
  static bool _initialized = false;

  static String? get token => _fcmToken;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1) Background handler (do once, early)
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2) Ask permission (iOS + Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final status = settings.authorizationStatus;
      print('📱 Notification permission status: $status');

      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        print('❌ Notifications not allowed, stopping setup.');
        return;
      }

      // 3) iOS: wait for APNs token (best-effort)
      if (Platform.isIOS) {
        final apns = await _waitForApnsToken(maxWaitSeconds: 8);
        print('🍎 APNs token: ${apns == null ? "NULL (check iOS setup)" : "${apns.substring(0, 20)}..."}');
      }

      // 4) Get FCM token
      final token = await _messaging.getToken();
      if (token == null) {
        print('⚠️ FCM token is null. Will rely on onTokenRefresh later.');
      } else {
        _fcmToken = token;
        print('✅ FCM token: ${token.substring(0, 20)}...');
        await _saveTokenToFirestore(token);
      }

      // 5) Foreground messages - show local notification when app is in foreground
      FirebaseMessaging.onMessage.listen((message) async {
        print('📨 Foreground message: ${message.messageId}');
        print('   Title: ${message.notification?.title}');
        print('   Body: ${message.notification?.body}');
        print('   Data: ${message.data}');
        
        // Show local notification when app is in foreground
        if (message.notification != null) {
          await NotificationService.showLocalNotification(
            title: message.notification!.title ?? 'Notification',
            body: message.notification!.body ?? '',
            payload: message.data.toString(),
          );
        }
      });

      // 6) User taps a notification (background → open)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('📨 Opened from notification: ${message.messageId}');
        print('   Data: ${message.data}');
      });

      // 7) App opened from terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('📨 Opened from terminated notification: ${initialMessage.messageId}');
        print('   Data: ${initialMessage.data}');
      }

      // 8) Token refresh (only ONE listener)
      _messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        print('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
        await _saveTokenToFirestore(newToken);
      });

    } catch (e) {
      print('❌ FCM initialize error: $e');
    }
  }

  static Future<String?> _waitForApnsToken({int maxWaitSeconds = 8}) async {
    for (int i = 0; i < maxWaitSeconds; i++) {
      final apns = await _messaging.getAPNSToken();
      if (apns != null) return apns;
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Not logged in; skipping token save.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': Platform.operatingSystem,
      }, SetOptions(merge: true));

      print('✅ Token saved to Firestore');
    } catch (e) {
      print('❌ Error saving token to Firestore: $e');
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('✅ Subscribed to $topic');
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('✅ Unsubscribed from $topic');
  }
}
