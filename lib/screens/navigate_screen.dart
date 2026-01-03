import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/parking_service.dart';
import '../services/location_service.dart';
import '../models/parking_session_model.dart';
import '../utils/marker_helper.dart';

class NavigateScreen extends StatefulWidget {
  final String sessionId;

  const NavigateScreen({super.key, required this.sessionId});

  @override
  State<NavigateScreen> createState() => _NavigateScreenState();
}

class _NavigateScreenState extends State<NavigateScreen> {
  final _locationService = LocationService();
  ParkingSession? _session;
  Position? _currentPosition;
  double? _distance;
  bool _isLoading = true;
  String? _mapError;
  MapType _selectedMapType = MapType.normal;
  BitmapDescriptor? _carIcon;
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  String _carIconColor = 'default'; // 'default', 'red', or 'black'

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _loadSession();
    _getCurrentLocation();
  }

  Future<void> _loadCarIcon() async {
    final icon = await MarkerHelper.createCarIconFromAsset(
      assetPath: 'assets/icon/carIcon.png',
      color: _carIconColor,
    );
    if (mounted) {
      setState(() {
        _carIcon = icon;
      });
    }
  }

  void _showCarColorSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Car Color',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26, width: 2),
                    ),
                    child: const Icon(Icons.circle, color: Colors.white, size: 20),
                  ),
                  title: const Text('Default'),
                  trailing: _carIconColor == 'default'
                      ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    setState(() {
                      _carIconColor = 'default';
                    });
                    _loadCarIcon();
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: const Text('Red'),
                  trailing: _carIconColor == 'red'
                      ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    setState(() {
                      _carIconColor = 'red';
                    });
                    _loadCarIcon();
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: const Text('Black'),
                  trailing: _carIconColor == 'black'
                      ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    setState(() {
                      _carIconColor = 'black';
                    });
                    _loadCarIcon();
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadSession() async {
    try {
      final parkingService = context.read<ParkingService>();
      final session = await parkingService.getSessionById(widget.sessionId);

      if (!mounted) return;
      
      // Debug: Print what we loaded
      if (session != null) {
        print('📍 Loaded parking session:');
        print('   ID: ${session.id}');
        print('   Lat: ${session.lat}');
        print('   Lng: ${session.lng}');
        print('   Altitude: ${session.altitude ?? "null"}');
        print('   Accuracy: ${session.accuracy}m');
      }
      
      setState(() {
        _session = session;
        _isLoading = false;
      });
      _calculateDistance();
      if (_currentPosition != null) {
        _updateRoute();
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading session: $e')),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      print('📍 NavigateScreen: Getting current location...');
      final position = await _locationService.getCurrentPosition(
        accuracy: LocationAccuracy.best,
      );
      
      if (position == null) {
        print('❌ NavigateScreen: Location service returned null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get your current location. Please check location permissions.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      print('✅ NavigateScreen: Current location received: ${position.latitude}, ${position.longitude}');
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _calculateDistance();
        _updateRoute();
        _updateCameraToShowBothLocations();
      }
    } catch (e) {
      print('❌ NavigateScreen: Error getting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _updateRoute() {
    if (_session != null && _currentPosition != null) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              LatLng(_session!.lat, _session!.lng),
            ],
            color: Colors.blue,
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            geodesic: true,
          ),
        };
      });
    }
  }

  Future<void> _updateCameraToShowBothLocations() async {
    if (_mapController != null && _session != null && _currentPosition != null) {
      // Calculate bounds to include both locations
      final double minLat = _currentPosition!.latitude < _session!.lat
          ? _currentPosition!.latitude
          : _session!.lat;
      final double maxLat = _currentPosition!.latitude > _session!.lat
          ? _currentPosition!.latitude
          : _session!.lat;
      final double minLng = _currentPosition!.longitude < _session!.lng
          ? _currentPosition!.longitude
          : _session!.lng;
      final double maxLng = _currentPosition!.longitude > _session!.lng
          ? _currentPosition!.longitude
          : _session!.lng;

      // Add padding
      final double latPadding = (maxLat - minLat) * 0.3;
      final double lngPadding = (maxLng - minLng) * 0.3;

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  void _calculateDistance() {
    if (_session != null && _currentPosition != null) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _session!.lat,
        _session!.lng,
      );
      setState(() => _distance = distance);
    }
  }

  void _showMapTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Map Type',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                _buildMapTypeOption(
                  context,
                  MapType.normal,
                  'Standard',
                  Icons.map,
                  'Default street map view',
                ),
                _buildMapTypeOption(
                  context,
                  MapType.satellite,
                  'Satellite',
                  Icons.satellite,
                  'Satellite imagery view',
                ),
                _buildMapTypeOption(
                  context,
                  MapType.hybrid,
                  'Hybrid',
                  Icons.layers,
                  'Satellite with street labels',
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapTypeOption(
    BuildContext context,
    MapType mapType,
    String title,
    IconData icon,
    String description,
  ) {
    final isSelected = _selectedMapType == mapType;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      subtitle: Text(description),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).primaryColor,
            )
          : null,
      onTap: () {
        setState(() {
          _selectedMapType = mapType;
        });
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Navigate')),
        body: const Center(child: Text('Session not found')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full screen map
          SafeArea(
            child: _mapError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Map Error',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _mapError!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _mapError = null);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_session!.lat, _session!.lng),
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('car'),
                        position: LatLng(_session!.lat, _session!.lng),
                        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                        infoWindow: InfoWindow(title: 'Your Car'),
                      ),
                      if (_currentPosition != null)
                        Marker(
                          markerId: const MarkerId('current'),
                          position: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueBlue,
                          ),
                          infoWindow: const InfoWindow(title: 'You'),
                        ),
                    },
                    circles: {
                      Circle(
                        circleId: const CircleId('geofence'),
                        center: LatLng(_session!.lat, _session!.lng),
                        radius: _session!.geofenceRadiusM,
                        fillColor: Colors.red.withValues(alpha: 0.2),
                        strokeColor: Colors.red,
                        strokeWidth: 2,
                      ),
                    },
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: _selectedMapType,
                    zoomControlsEnabled: true,
                    onMapCreated: (GoogleMapController controller) async {
                      print('✅ Google Map created successfully');
                      print('📍 Map center: ${_session!.lat}, ${_session!.lng}');
                      _mapController = controller;
                      
                      if (mounted) {
                        setState(() => _mapError = null);
                        
                        // Wait a bit for map to initialize, then update camera
                        await Future.delayed(const Duration(milliseconds: 500));
                        if (_currentPosition != null) {
                          _updateCameraToShowBothLocations();
                        }
                      }
                    },
                  ),
          ),
          // Back button - positioned at top left
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    // Always go to home screen when back is pressed
                    context.go('/home');
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ),
          ),
          // Map type selector button - positioned at top right
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: const Icon(Icons.layers, color: Colors.black),
                      onPressed: _showMapTypeSelector,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Map Type',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.black),
                      onPressed: _getCurrentLocation,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Update My Location',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: Icon(
                        Icons.palette,
                        color: _carIconColor == 'red' ? Colors.red : Colors.black,
                      ),
                      onPressed: _showCarColorSelector,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Change Car Icon Color',
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom info panel - positioned over the map
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_distance != null) ...[
                  Text(
                    'Distance: ${_distance!.toStringAsFixed(0)}m',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                const Text('Car Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Latitude: ${_session!.lat.toStringAsFixed(6)}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                Text(
                  'Longitude: ${_session!.lng.toStringAsFixed(6)}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                if (_session!.altitude != null)
                  Text(
                    'Altitude: ${_session!.altitude!.toStringAsFixed(1)}m',
                    style: const TextStyle(fontFamily: 'monospace'),
                  )
                else
                  Text(
                    'Altitude: Not recorded',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Text(
                  'Accuracy: ${_session!.accuracy.toStringAsFixed(1)}m',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_currentPosition != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const Text('Your Current Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  Text(
                    'Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  if (_currentPosition!.altitude != 0.0)
                    Text(
                      'Altitude: ${_currentPosition!.altitude.toStringAsFixed(1)}m',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  Text(
                    'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Getting your location...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                if (_session!.aiParsed != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const Text('Parking Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_session!.aiParsed!.level != null)
                    Text('Level: ${_session!.aiParsed!.level}'),
                  if (_session!.aiParsed!.gate != null)
                    Text('Gate: ${_session!.aiParsed!.gate}'),
                  if (_session!.aiParsed!.zone != null)
                    Text('Zone: ${_session!.aiParsed!.zone}'),
                  if (_session!.aiParsed!.landmark != null)
                    Text('Landmark: ${_session!.aiParsed!.landmark}'),
                ],
                // if (_session!.rawNote != null) ...[
                //   const Divider(),
                //   Text('Note: ${_session!.rawNote}'),
                // ],
                if (_session!.aiConfidence != null) ...[
                  const Divider(),
                  Text(
                    'Confidence: ${_session!.aiConfidence!.score}/5',
                    style: TextStyle(
                      color: _session!.aiConfidence!.score >= 4
                          ? Colors.green
                          : _session!.aiConfidence!.score >= 3
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                  Text(
                    _session!.aiConfidence!.reason,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          )],
      ),
    );
  }
}

//