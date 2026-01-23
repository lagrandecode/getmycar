import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../services/location_service.dart';
import '../services/parking_service.dart';
import '../services/ai_service.dart';
import '../models/parking_session_model.dart';
import '../widgets/map_background.dart';

class SaveParkingScreen extends StatefulWidget {
  const SaveParkingScreen({super.key});

  @override
  State<SaveParkingScreen> createState() => _SaveParkingScreenState();
}

class _SaveParkingScreenState extends State<SaveParkingScreen> {
  final _noteController = TextEditingController();
  final _locationService = LocationService();
  File? _photo;
  Position? _position;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isParsingNote = false;
  AIParsed? _aiParsed;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      print('📍 Requesting location...');
      
      final position = await _locationService.getCurrentPosition(
        accuracy: LocationAccuracy.best, // Use best accuracy for real GPS
        context: context,
      );
      
      if (position == null) {
        print('❌ Location service returned null');
        if (mounted) {
          setState(() => _isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get location. Please check location permissions in settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      print('✅ Location received: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
      
      if (mounted) {
        setState(() {
          _position = position;
          _isGettingLocation = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location captured! Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error getting location: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() => _isGettingLocation = false);
        
        String errorMessage = 'Error getting location';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('permission') || errorStr.contains('denied')) {
          errorMessage = 'Location permission denied.\n\nPlease:\n1. Go to Settings → Privacy & Security → Location Services\n2. Enable Location Services\n3. Find "getmycar" and select "While Using the App"\n4. Try again';
        } else if (errorStr.contains('timeout')) {
          errorMessage = 'Location request timed out. Please ensure you have a clear view of the sky for GPS and try again.';
        } else if (errorStr.contains('disabled')) {
          errorMessage = 'Location services are disabled. Please enable them in Settings.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image != null && mounted) {
      setState(() => _photo = File(image.path));
    }
  }

  Future<void> _parseNoteWithAI() async {
    if (_noteController.text.trim().isEmpty) return;

    setState(() => _isParsingNote = true);

    try {
      final aiService = context.read<AIService>();
      final parsed = await aiService.parseParkingNote(_noteController.text);

      if (mounted) {
        setState(() {
          _aiParsed = parsed;
          _isParsingNote = false;
        });

        if (parsed != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note parsed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isParsingNote = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing note: $e')),
        );
      }
    }
  }

  Future<void> _saveParking() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please get your location first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final parkingService = context.read<ParkingService>();
      final aiService = context.read<AIService>();

      // Get AI confidence advisor
      AIConfidence? aiConfidence;
      try {
        aiConfidence = await aiService.getConfidenceAdvisor(
          gpsAccuracy: _position!.accuracy,
          isUnderground: false, // Could be detected from sensors
          hasPhoto: _photo != null,
          hasNote: _noteController.text.trim().isNotEmpty,
        );
      } catch (e) {
        print('Error getting confidence advisor: $e');
      }

      // Create session - always save altitude, even if 0.0
      final session = ParkingSession(
        lat: _position!.latitude,
        lng: _position!.longitude,
        accuracy: _position!.accuracy,
        altitude: _position!.altitude != 0.0 ? _position!.altitude : null,
        savedAt: DateTime.now(),
        active: true,
        geofenceRadiusM: aiConfidence?.score != null
            ? (aiConfidence!.score * 12.0).clamp(30.0, 100.0)
            : 30.0,
        source: 'manual',
        rawNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        aiParsed: _aiParsed,
        aiConfidence: aiConfidence,
      );
      
      // Debug: Print what we're saving
      print('💾 Saving parking session:');
      print('   Lat: ${session.lat}');
      print('   Lng: ${session.lng}');
      print('   Altitude: ${session.altitude ?? "null"}');
      print('   Accuracy: ${session.accuracy}m');

      // Save session
      final sessionId = await parkingService.saveParkingSession(session);

      // Upload photo if exists
      String? photoUrl;
      if (_photo != null) {
        photoUrl = await parkingService.uploadPhoto(_photo!, sessionId);
        if (photoUrl != null) {
          await parkingService.updateParkingSession(
            sessionId,
            session.copyWith(photoUrl: photoUrl),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parking spot saved!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving parking: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [IconButton(onPressed: ()=>context.go('/home'), icon: Icon(Icons.arrow_back))],
        title: const Text('Save Parking Spot'),
      ),
      body: MapBackground(
        child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.directions_car, size: 48, color: Colors.blue),
                    const SizedBox(height: 16),
                    if (_position != null) ...[
                      Text(
                        'Latitude: ${_position!.latitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Longitude: ${_position!.longitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_position!.altitude != 0.0)
                        Text(
                          'Altitude: ${_position!.altitude.toStringAsFixed(1)}m',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        Text(
                          'Altitude: Not available',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Accuracy: ${_position!.accuracy.toStringAsFixed(1)}m',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ] else
                      const Text('Location not captured'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isGettingLocation ? null : _getCurrentLocation,
                      icon: _isGettingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.directions_car),
                      label: Text(_isGettingLocation ? 'Getting location...' : 'Get Location'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'e.g., "P2 near Gate 7, blue elevator"',
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                      onChanged: (_) {
                        setState(() => _aiParsed = null);
                      },
                    ),
                    if (_noteController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isParsingNote ? null : _parseNoteWithAI,
                        icon: _isParsingNote
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: const Text('Parse with AI'),
                      ),
                    ],
                    if (_aiParsed != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const Text('Parsed Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (_aiParsed!.level != null)
                        Text('Level: ${_aiParsed!.level}'),
                      if (_aiParsed!.gate != null)
                        Text('Gate: ${_aiParsed!.gate}'),
                      if (_aiParsed!.slot != null)
                        Text('Slot: ${_aiParsed!.slot}'),
                      if (_aiParsed!.zone != null)
                        Text('Zone: ${_aiParsed!.zone}'),
                      if (_aiParsed!.landmark != null)
                        Text('Landmark: ${_aiParsed!.landmark}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Photo (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_photo != null)
                      Image.file(_photo!, height: 200, fit: BoxFit.cover)
                    else
                      const Text('No photo taken'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_isLoading || _position == null) ? null : _saveParking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Save Parking Spot'),
            ),
          ],
          ),
        ),
        ),
      ),
    );
  }
}


