import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'parking_service.dart';
import 'notification_service.dart';
import '../models/parking_session_model.dart';

/// Service for detecting Bluetooth car connections and automatically
/// saving parking locations when the phone disconnects from the car.
class BluetoothService {
  static BluetoothService? _instance;
  static BluetoothService get instance => _instance ??= BluetoothService._();
  
  BluetoothService._();

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  Timer? _monitoringTimer;
  
  bool _isInitialized = false;
  bool _isMonitoring = false;
  String? _connectedCarDeviceId;
  final LocationService _locationService = LocationService();
  
  // Car-related device name patterns (case-insensitive matching)
  final List<String> _carNamePatterns = [
    'car',
    'bmw',
    'mercedes',
    'mercedes-benz',
    'toyota',
    'honda',
    'ford',
    'nissan',
    'audi',
    'volvo',
    'lexus',
    'acura',
    'infiniti',
    'mazda',
    'subaru',
    'hyundai',
    'kia',
    'volkswagen',
    'vw',
    'jeep',
    'chevrolet',
    'chevy',
    'gmc',
    'cadillac',
    'lincoln',
    'tesla',
    'porsche',
    'jaguar',
    'land rover',
    'range rover',
    'mini',
    'fiat',
    'alfa romeo',
    'hands-free',
    'hands free',
    'handsfree',
    'carkit',
    'car kit',
    'car-kit',
    'bluetooth',
    'X-12',
  ];

  /// Initialize Bluetooth service and request permissions
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔵 BluetoothService: Initializing...');
      
      // Check Bluetooth permissions
      final hasPermission = await _requestBluetoothPermissions();
      if (!hasPermission) {
        print('⚠️ BluetoothService: Permissions not granted');
        _isInitialized = true; // Mark as initialized to prevent retry loops
        return;
      }
      
      // Check if Bluetooth is available on the device
      final adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ BluetoothService: Bluetooth adapter not available');
          return BluetoothAdapterState.unknown;
        },
      );
      
      if (adapterState != BluetoothAdapterState.on) {
        print('⚠️ BluetoothService: Bluetooth is not enabled');
        _isInitialized = true;
        return;
      }
      
      _isInitialized = true;
      print('✅ BluetoothService: Initialized successfully');
    } catch (e) {
      print('❌ BluetoothService: Initialization error: $e');
      _isInitialized = true; // Mark as initialized to prevent retry loops
    }
  }

  /// Request Bluetooth and location permissions
  Future<bool> _requestBluetoothPermissions() async {
    try {
      // Request Bluetooth permissions
      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }
      if (await Permission.bluetoothConnect.isDenied) {
        await Permission.bluetoothConnect.request();
      }
      
      // Check Bluetooth permissions status
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;
      
      final hasBluetoothPermission = scanStatus.isGranted && connectStatus.isGranted;
      
      // Request location permission (needed for saving parking spot)
      final locationStatus = await Permission.location.status;
      if (locationStatus.isDenied) {
        await Permission.location.request();
      }
      final hasLocationPermission = (await Permission.location.status).isGranted;
      
      if (!hasBluetoothPermission) {
        print('❌ BluetoothService: Bluetooth permissions not granted');
        return false;
      }
      
      if (!hasLocationPermission) {
        print('⚠️ BluetoothService: Location permission not granted (required for parking save)');
        // Continue anyway - location will be requested when needed
      }
      
      return true;
    } catch (e) {
      print('❌ BluetoothService: Error requesting permissions: $e');
      return false;
    }
  }

  /// Start monitoring Bluetooth connections for car devices
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      print('⚠️ BluetoothService: Already monitoring');
      return;
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      print('🔵 BluetoothService: Starting Bluetooth monitoring...');
      _isMonitoring = true;
      
      // Monitor adapter state changes
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        print('🔵 BluetoothService: Adapter state: $state');
        if (state == BluetoothAdapterState.on && !_isMonitoring) {
          // Restart monitoring if Bluetooth is turned back on
          startMonitoring();
        } else if (state != BluetoothAdapterState.on) {
          _connectedCarDeviceId = null;
        }
      });
      
      // Monitor connected devices periodically (every 5 seconds)
      _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _checkConnectedDevices();
      });
      
      // Check initial connected devices
      _checkConnectedDevices();
      
      print('✅ BluetoothService: Monitoring started');
    } catch (e) {
      print('❌ BluetoothService: Error starting monitoring: $e');
      _isMonitoring = false;
    }
  }

  /// Stop monitoring Bluetooth connections
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    print('🔵 BluetoothService: Stopping monitoring...');
    _isMonitoring = false;
    _connectedCarDeviceId = null;
    
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
    
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    print('✅ BluetoothService: Monitoring stopped');
  }

  /// Check connected devices periodically
  Future<void> _checkConnectedDevices() async {
    if (!_isMonitoring) return;
    
    try {
      // connectedDevices is a synchronous getter, not async
      final devices = FlutterBluePlus.connectedDevices;
      _handleConnectedDevices(devices);
    } catch (e) {
      // Silently handle errors - Bluetooth might be unavailable
      if (_isMonitoring) {
        // Only log if we're still monitoring (not during shutdown)
        print('⚠️ BluetoothService: Error checking connected devices: $e');
      }
    }
  }

  /// Handle connected devices list changes
  void _handleConnectedDevices(List<BluetoothDevice> devices) {
    // Check if any connected device is a car
    BluetoothDevice? carDevice;
    for (final device in devices) {
      if (_isCarDevice(device)) {
        carDevice = device;
        break;
      }
    }
    
    if (carDevice != null) {
      // Car device connected
      if (_connectedCarDeviceId != carDevice.remoteId.str) {
        _connectedCarDeviceId = carDevice.remoteId.str;
        _onCarConnected(carDevice);
      }
    } else {
      // No car device connected
      if (_connectedCarDeviceId != null) {
        final disconnectedId = _connectedCarDeviceId!;
        _connectedCarDeviceId = null;
        _onCarDisconnected(disconnectedId);
      }
    }
  }

  /// Check if a device appears to be a car Bluetooth system
  bool _isCarDevice(BluetoothDevice device) {
    final deviceName = device.platformName.toLowerCase();
    
    // Check device name against car patterns
    for (final pattern in _carNamePatterns) {
      if (deviceName.contains(pattern.toLowerCase())) {
        print('🔵 BluetoothService: Car device detected: ${device.platformName}');
        return true;
      }
    }
    
    return false;
  }

  /// Handle car Bluetooth connection
  Future<void> _onCarConnected(BluetoothDevice device) async {
    print('🚗 BluetoothService: Car connected - ${device.platformName}');
    
    try {
      // Show notification
      await NotificationService.showCarConnectedNotification();
      print('✅ BluetoothService: Connection notification shown');
    } catch (e) {
      print('❌ BluetoothService: Error showing connection notification: $e');
    }
  }

  /// Handle car Bluetooth disconnection
  Future<void> _onCarDisconnected(String deviceId) async {
    print('🚗 BluetoothService: Car disconnected - $deviceId');
    
    try {
      // Capture location immediately
      print('📍 BluetoothService: Capturing location on car disconnect...');
      final position = await _locationService.getCurrentPosition(
        accuracy: LocationAccuracy.best,
      );
      
      if (position == null) {
        print('❌ BluetoothService: Failed to get location');
        return;
      }
      
      print('✅ BluetoothService: Location captured: ${position.latitude}, ${position.longitude}');
      
      // Save parking session
      await _saveParkingLocation(position);
      print('✅ BluetoothService: Parking location saved');
    } catch (e) {
      print('❌ BluetoothService: Error handling car disconnect: $e');
    }
  }

  /// Save parking location to Firestore
  Future<void> _saveParkingLocation(Position position) async {
    try {
      final parkingService = ParkingService();
      
      // Create parking session
      final session = ParkingSession(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude != 0.0 ? position.altitude : null,
        savedAt: DateTime.now(),
        active: true,
        geofenceRadiusM: 50.0, // Default geofence radius
        source: 'bluetooth_disconnect', // Mark as auto-saved
        rawNote: 'Auto-saved on car Bluetooth disconnect',
      );
      
      // Save to Firestore
      await parkingService.saveParkingSession(session);
      
      // Show notification
      await NotificationService.showParkingSavedNotification(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude != 0.0 ? position.altitude : null,
      );
    } catch (e) {
      print('❌ BluetoothService: Error saving parking location: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _instance = null;
  }
}

