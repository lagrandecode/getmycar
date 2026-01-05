import 'package:geolocator/geolocator.dart';
import 'parking_service.dart';
import 'location_service.dart';
import '../models/parking_session_model.dart';
import 'notification_service.dart';

/// Service for capturing GPS location when car Bluetooth disconnects
/// and saving it as a parking session
class CarLocationCapture {
  final LocationService _locationService = LocationService();
  
  /// Capture current location and save as parking session
  /// Called automatically when car Bluetooth disconnects
  Future<void> captureAndSaveLocation() async {
    try {
      print('📍 CarLocationCapture: Starting location capture...');
      
      // Get current position with best accuracy
      final position = await _locationService.getCurrentPosition(
        accuracy: LocationAccuracy.best,
      );
      
      if (position == null) {
        print('❌ CarLocationCapture: Failed to get location');
        return;
      }
      
      print('✅ CarLocationCapture: Location captured - Lat: ${position.latitude}, Lng: ${position.longitude}, Accuracy: ${position.accuracy}m');
      
      // Save parking session
      await _saveParkingSession(position);
      
      print('✅ CarLocationCapture: Parking session saved successfully');
    } catch (e) {
      print('❌ CarLocationCapture: Error capturing location: $e');
      rethrow;
    }
  }

  /// Save parking session to Firestore
  Future<void> _saveParkingSession(Position position) async {
    try {
      final parkingService = ParkingService();
      
      // Create parking session with car disconnect source
      final session = ParkingSession(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude != 0.0 ? position.altitude : null,
        savedAt: DateTime.now(),
        active: true,
        geofenceRadiusM: 50.0, // Default geofence radius
        source: 'car_bluetooth_disconnect', // Mark as auto-saved from car Bluetooth
        rawNote: 'Auto-saved on car Bluetooth disconnect',
      );
      
      // Save to Firestore (this will deactivate previous sessions)
      await parkingService.saveParkingSession(session);
      
      // Show parking saved notification
      await NotificationService.showParkingSavedNotification(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude != 0.0 ? position.altitude : null,
      );
    } catch (e) {
      print('❌ CarLocationCapture: Error saving parking session: $e');
      rethrow;
    }
  }
}

