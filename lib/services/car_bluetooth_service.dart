import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

/// Service for detecting car Bluetooth connections using platform channels.
/// 
/// Android: Uses native Bluetooth APIs to detect Bluetooth Classic connections
/// iOS: Uses AVAudioSession route changes (best-effort, limited by iOS restrictions)
class CarBluetoothService {
  static const MethodChannel _channel = MethodChannel('com.findmycar/car_bluetooth');
  static CarBluetoothService? _instance;
  static CarBluetoothService get instance => _instance ??= CarBluetoothService._();
  
  CarBluetoothService._();

  static const EventChannel _eventChannel = EventChannel('com.findmycar/car_bluetooth_events');
  StreamController<bool>? _connectionController;
  Stream<bool>? _connectionStream;
  StreamSubscription<dynamic>? _eventSubscription;
  bool _isInitialized = false;
  bool _isCarConnected = false;
  String? _selectedCarDeviceId;
  
  // Car-related device name patterns (case-insensitive)
  static const List<String> _carNamePatterns = [
    'car', 'auto', 'bmw', 'mercedes', 'mercedes-benz', 'toyota', 'honda',
    'ford', 'nissan', 'audi', 'volvo', 'lexus', 'acura', 'infiniti',
    'mazda', 'subaru', 'hyundai', 'kia', 'volkswagen', 'vw', 'jeep',
    'chevrolet', 'chevy', 'gmc', 'cadillac', 'lincoln', 'tesla',
    'porsche', 'jaguar', 'land rover', 'range rover', 'mini', 'fiat',
    'sync', 'uconnect', 'mmi', 'hands-free', 'hands free', 'handsfree',
    'carkit', 'car kit', 'car-kit', 'myford touch', 'entune',
  ];

  // Common headphone/earbud patterns to exclude
  static const List<String> _headphonePatterns = [
    'airpods', 'airpod', 'beats', 'sony', 'bose', 'jbl', 'sennheiser',
    'audio-technica', 'headphones', 'headphone', 'earbuds', 'earbud',
    'earphones', 'earphone', 'earpods', 'galaxy buds', 'pixel buds',
  ];

  /// Initialize the service and load saved "My Car" device
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🚗 CarBluetoothService: Initializing...');
      
      // Load saved "My Car" device ID
      final prefs = await SharedPreferences.getInstance();
      _selectedCarDeviceId = prefs.getString('selected_car_device_id');
      
      if (_selectedCarDeviceId != null) {
        print('🚗 CarBluetoothService: Loaded saved car device: $_selectedCarDeviceId');
      } else {
        print('🚗 CarBluetoothService: No saved car device - will use heuristic detection');
      }
      
      _connectionController = StreamController<bool>.broadcast();
      _connectionStream = _connectionController!.stream;
      
      // Set up event channel listener for connection events
      // Handle gracefully if platform implementation is not available
      try {
        final stream = _eventChannel.receiveBroadcastStream();
        _eventSubscription = stream.listen(
          _onPlatformEvent,
          onError: (error) {
            // MissingPluginException is expected if platform implementation is disabled
            final errorStr = error.toString();
            if (errorStr.contains('MissingPluginException') || 
                errorStr.contains('No implementation found')) {
              print('⚠️ CarBluetoothService: Platform implementation not available (CarBluetoothHandler may be disabled)');
            } else {
              print('❌ CarBluetoothService: Event channel error: $error');
            }
          },
          cancelOnError: false,
        );
      } catch (e) {
        // Handle MissingPluginException gracefully
        final errorStr = e.toString();
        if (errorStr.contains('MissingPluginException') || 
            errorStr.contains('No implementation found')) {
          print('⚠️ CarBluetoothService: Platform implementation not available (CarBluetoothHandler may be disabled)');
        } else {
          print('⚠️ CarBluetoothService: Event channel setup error: $e');
        }
        // Continue without event channel - feature will be disabled
      }
      
      // Initialize platform side
      try {
        await _channel.invokeMethod('initialize');
        print('✅ CarBluetoothService: Platform initialization successful');
      } catch (e) {
        print('⚠️ CarBluetoothService: Platform initialization error (may be expected on iOS): $e');
      }
      
      _isInitialized = true;
      print('✅ CarBluetoothService: Initialized successfully');
    } catch (e) {
      print('❌ CarBluetoothService: Initialization error: $e');
      _isInitialized = true; // Mark as initialized to prevent retry loops
    }
  }

  /// Handle platform events from event channel
  void _onPlatformEvent(dynamic event) {
    try {
      final Map<dynamic, dynamic> eventMap = event as Map<dynamic, dynamic>;
      final isConnected = eventMap['isConnected'] as bool;
      final deviceId = eventMap['deviceId'] as String?;
      final deviceName = eventMap['deviceName'] as String?;
      
      print('🚗 CarBluetoothService: Connection changed - connected: $isConnected, device: $deviceName');
      
      _handleConnectionChange(isConnected, deviceId, deviceName);
    } catch (e) {
      print('❌ CarBluetoothService: Error handling platform event: $e');
    }
  }

  /// Handle Bluetooth connection state change
  void _handleConnectionChange(bool isConnected, String? deviceId, String? deviceName) {
    if (_selectedCarDeviceId != null) {
      // User has selected a specific car device
      if (deviceId == _selectedCarDeviceId) {
        _isCarConnected = isConnected;
        _connectionController?.add(isConnected);
      }
    } else {
      // Use heuristic detection
      if (deviceName != null && _isCarDeviceByName(deviceName)) {
        _isCarConnected = isConnected;
        _connectionController?.add(isConnected);
      }
    }
  }

  /// Check if device name matches car patterns (excluding headphones)
  bool _isCarDeviceByName(String deviceName) {
    final lowerName = deviceName.toLowerCase();
    
    // First check if it's a headphone (exclude these)
    for (final pattern in _headphonePatterns) {
      if (lowerName.contains(pattern.toLowerCase())) {
        print('🚗 CarBluetoothService: Device excluded (headphone): $deviceName');
        return false;
      }
    }
    
    // Then check if it matches car patterns
    for (final pattern in _carNamePatterns) {
      if (lowerName.contains(pattern.toLowerCase())) {
        print('🚗 CarBluetoothService: Car device detected (heuristic): $deviceName');
        return true;
      }
    }
    
    return false;
  }

  /// Start monitoring Bluetooth connections
  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      print('🚗 CarBluetoothService: Starting monitoring...');
      await _channel.invokeMethod('startMonitoring');
      print('✅ CarBluetoothService: Monitoring started');
    } catch (e) {
      print('❌ CarBluetoothService: Error starting monitoring: $e');
    }
  }

  /// Stop monitoring Bluetooth connections
  Future<void> stopMonitoring() async {
    try {
      print('🚗 CarBluetoothService: Stopping monitoring...');
      await _channel.invokeMethod('stopMonitoring');
      print('✅ CarBluetoothService: Monitoring stopped');
    } catch (e) {
      print('❌ CarBluetoothService: Error stopping monitoring: $e');
    }
  }

  /// Get stream of car connection state changes
  /// true = connected, false = disconnected
  Stream<bool> get connectionStream {
    if (_connectionStream == null) {
      _connectionStream = StreamController<bool>.broadcast().stream;
    }
    return _connectionStream!;
  }

  /// Get current connection state
  bool get isCarConnected => _isCarConnected;

  /// Get list of paired Bluetooth devices (for settings screen)
  /// Returns list of maps: {id: String, name: String, isConnected: bool}
  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    try {
      final result = await _channel.invokeMethod('getPairedDevices');
      final List<dynamic> devices = result as List<dynamic>;
      
      return devices.map((device) {
        return {
          'id': device['id'] as String,
          'name': device['name'] as String,
          'isConnected': device['isConnected'] as bool? ?? false,
        };
      }).toList();
    } catch (e) {
      print('❌ CarBluetoothService: Error getting paired devices: $e');
      return [];
    }
  }

  /// Save selected "My Car" device
  Future<void> setSelectedCarDevice(String? deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (deviceId != null) {
        await prefs.setString('selected_car_device_id', deviceId);
        _selectedCarDeviceId = deviceId;
        print('✅ CarBluetoothService: Saved car device: $deviceId');
      } else {
        await prefs.remove('selected_car_device_id');
        _selectedCarDeviceId = null;
        print('✅ CarBluetoothService: Cleared saved car device');
      }
    } catch (e) {
      print('❌ CarBluetoothService: Error saving car device: $e');
    }
  }

  /// Get selected "My Car" device ID
  String? get selectedCarDeviceId => _selectedCarDeviceId;

  /// Dispose resources
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _connectionController?.close();
    _connectionController = null;
    _connectionStream = null;
    _instance = null;
  }
}

