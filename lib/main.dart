import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'services/auth_service.dart';
import 'services/parking_service.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/car_bluetooth_service.dart';
import 'services/car_location_capture.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/save_parking_screen.dart';
import 'screens/navigate_screen.dart';
import 'screens/history_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/settings_screen.dart';
import 'screens/car_bluetooth_settings_screen.dart';
import 'screens/onboarding_paywall_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  
  // Initialize notification service
  await NotificationService.initialize();
  
  // Initialize Firebase with explicit options
  // This ensures Firebase works even if the plist/json files aren't in the bundle
  try {
    FirebaseOptions? options;
    
    if (Platform.isIOS) {
      // iOS Firebase configuration from GoogleService-Info.plist
      options = const FirebaseOptions(
        apiKey: 'AIzaSyBUUzI_gL2UcMPG0HF4dSjYdJxcc98oyhU',
        appId: '1:959667247262:ios:0f66e37057f1d19edd038f',
        messagingSenderId: '959667247262',
        projectId: 'getmycar-85be4',
        storageBucket: 'getmycar-85be4.firebasestorage.app',
        iosBundleId: 'com.lagrangecode.getmycar', // Use actual bundle ID
      );
    } else if (Platform.isAndroid) {
      // Android Firebase configuration - will auto-detect from google-services.json
      // But we can also provide explicit options if needed
      options = null; // Let it auto-detect from google-services.json
    }
    
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      // For Android, try auto-detection
      await Firebase.initializeApp();
    }
    
    // Verify Firebase initialized successfully
    if (Firebase.apps.isNotEmpty) {
      final app = Firebase.app(); // Gets the default app
      print('✅ Firebase initialized successfully');
      print('✅ Firebase app name: ${app.name} (this is normal - [DEFAULT] is the standard name)');
      print('✅ Firebase project ID: ${app.options.projectId}');
    } else {
      throw Exception('Firebase apps list is empty after initialization');
    }
  } catch (e, stackTrace) {
    print('❌ Firebase initialization failed!');
    print('Error: $e');
    print('Stack trace: $stackTrace');
    
    // Try fallback initialization without options
    try {
      print('🔄 Attempting fallback Firebase initialization...');
      await Firebase.initializeApp();
      print('✅ Fallback initialization succeeded');
    } catch (e2) {
      print('❌ Fallback also failed: $e2');
      print('⚠️  App will continue but Firebase features may not work');
    }
  }
  
  // Initialize Firebase Cloud Messaging after Firebase is initialized
  try {
    await FCMService.initialize();
    print('✅ FCM initialized successfully');
  } catch (e) {
    print('❌ FCM initialization failed: $e');
    print('⚠️  Push notifications may not work');
  }
  
  // Initialize Car Bluetooth service for car connection detection
  // Note: This may fail gracefully if platform implementation is not available
  try {
    await CarBluetoothService.instance.initialize();
    await _setupCarBluetoothListener();
    await CarBluetoothService.instance.startMonitoring();
    print('✅ Car Bluetooth service initialized and monitoring started');
  } catch (e) {
    print('⚠️ Car Bluetooth service initialization failed (this is OK if platform implementation is disabled): $e');
    print('⚠️  Car Bluetooth connection detection will not work');
  }
  
  runApp(const MyApp());
}

/// Setup listener for car Bluetooth connection changes
Future<void> _setupCarBluetoothListener() async {
  final carBluetoothService = CarBluetoothService.instance;
  final carLocationCapture = CarLocationCapture();
  
  carBluetoothService.connectionStream.listen((isConnected) async {
    try {
      if (isConnected) {
        // Car connected - show notification
        print('🚗 Car Bluetooth connected - showing notification');
        await NotificationService.showCarConnectedNotificationSimple();
      } else {
        // Car disconnected - capture location and save
        print('🚗 Car Bluetooth disconnected - capturing location...');
        await carLocationCapture.captureAndSaveLocation();
        print('✅ Location captured and saved after car disconnect');
      }
    } catch (e) {
      print('❌ Error handling car Bluetooth connection change: $e');
    }
  });
  
  print('✅ Car Bluetooth listener set up');
}

final _router = GoRouter(
  initialLocation: '/onboarding-paywall',
  routes: [
    GoRoute(
      path: '/onboarding-paywall',
      builder: (context, state) => const OnboardingPaywallScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigation(),
    ),
    GoRoute(
      path: '/save-parking',
      builder: (context, state) => const SaveParkingScreen(),
    ),
    GoRoute(
      path: '/navigate/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return NavigateScreen(sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/car-bluetooth-settings',
      builder: (context, state) => const CarBluetoothSettingsScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ParkingService>(create: (_) => ParkingService()),
        Provider<AIService>(create: (_) => AIService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'getmycar',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
              brightness: Brightness.light,
              textTheme: GoogleFonts.spaceGroteskTextTheme(),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              brightness: Brightness.dark,
              textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
            ),
            themeMode: themeProvider.flutterThemeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

