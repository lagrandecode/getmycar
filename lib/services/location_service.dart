import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  Future<bool> checkPermissions() async {
    // Check location service status first
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('⚠️ Location services are disabled');
      return false;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    print('📍 Current permission status: $permission');

    if (permission == LocationPermission.denied) {
      print('🔐 Requesting location permission...');
      permission = await Geolocator.requestPermission();
      print('📍 Permission result: $permission');
      
      if (permission == LocationPermission.denied) {
        print('❌ Location permission denied by user');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Location permission permanently denied');
      // Optionally open app settings
      // await openAppSettings();
      return false;
    }

    // Permission is granted (either whileInUse or always)
    print('✅ Location permission granted: $permission');
    return true;
  }

  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    print('🔐 Checking location permissions...');
    final hasPermission = await checkPermissions();
    
    if (!hasPermission) {
      print('❌ Location permission not granted');
      throw Exception('Location permission not granted. Please enable location access in Settings.');
    }
    
    print('✅ Permission granted, requesting location...');

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        throw Exception('Location services are disabled. Please enable them in Settings.');
      }

      print('📍 Getting current position with accuracy: $accuracy');
      
      // Force fresh location - don't use cached location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: const Duration(seconds: 30), // Increased timeout for better accuracy
          distanceFilter: 0, // Don't filter by distance - get exact location
        ),
        forceAndroidLocationManager: false, // Use GPS provider
        desiredAccuracy: accuracy,
      );
      
      // Validate the position - reject invalid or default locations
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        print('❌ Invalid position received (0,0)');
        throw Exception('Invalid location received (0,0). Please ensure GPS is enabled and try again.');
      }
      
      // Reject default iOS simulator location (San Francisco)
      if ((position.latitude - 37.785834).abs() < 0.001 && 
          (position.longitude - (-122.406417)).abs() < 0.001) {
        print('❌ Default simulator location detected - rejecting');
        throw Exception('Default simulator location detected. Please use a real device with GPS or set a custom location in the simulator.');
      }
      
      // Reject any location with very poor accuracy (likely invalid)
      if (position.accuracy > 1000) {
        print('❌ Location accuracy too poor: ${position.accuracy}m');
        throw Exception('GPS accuracy is too poor (${position.accuracy.toStringAsFixed(0)}m). Please ensure you have a clear view of the sky and try again.');
      }
      
      print('✅ Position received: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
      print('   Altitude: ${position.altitude}m');
      print('   Speed: ${position.speed}m/s');
      print('   Heading: ${position.heading}°');
      print('   Timestamp: ${position.timestamp}');
      
      return position;
    } on TimeoutException catch (e) {
      print('❌ Location request timed out: $e');
      throw Exception('Location request timed out. Please ensure you have a clear view of the sky for GPS.');
    } catch (e) {
      print('❌ Error getting location: $e');
      rethrow; // Re-throw so the UI can handle it
    }
  }

  Future<double> calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    );
  }
}

