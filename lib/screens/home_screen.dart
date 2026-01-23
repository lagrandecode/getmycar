import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/parking_service.dart';
import '../services/location_service.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../models/parking_session_model.dart';
import '../widgets/map_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = LocationService();
  bool _isSavingNewLocation = false;
  late ConfettiController _confettiController;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _checkFirstTimeSignIn();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstTimeSignIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final createdAt = userDoc.data()?['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final timeDiff = DateTime.now().difference(createdAt.toDate());
          // If user document was created within last 10 seconds, show confetti
          if (timeDiff.inSeconds < 10 && mounted) {
            setState(() {
              _showConfetti = true;
            });
            _confettiController.play();
            // Hide confetti after animation
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _showConfetti = false;
                });
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error checking first-time sign-in: $e');
    }
  }

  Future<void> _findMyCarAndSaveNewLocation(ParkingSession currentSession) async {
    if (_isSavingNewLocation) return;

    setState(() => _isSavingNewLocation = true);

    try {
      // Get current location
      print('📍 Finding my car: Getting current location...');
      final position = await _locationService.getCurrentPosition(
        accuracy: LocationAccuracy.best,
        context: context,
      );

      if (position == null) {
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

      print('✅ Current location received: ${position.latitude}, ${position.longitude}');

      // Get services
      final parkingService = context.read<ParkingService>();
      final aiService = context.read<AIService>();

      // Get AI confidence advisor
      AIConfidence? aiConfidence;
      try {
        aiConfidence = await aiService.getConfidenceAdvisor(
          gpsAccuracy: position.accuracy,
          isUnderground: false,
          hasPhoto: false,
          hasNote: false,
        );
      } catch (e) {
        print('Error getting confidence advisor: $e');
      }

      // Create new parking session with current location
      final newSession = ParkingSession(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude != 0.0 ? position.altitude : null,
        savedAt: DateTime.now(),
        active: true,
        geofenceRadiusM: aiConfidence?.score != null
            ? (aiConfidence!.score * 12.0).clamp(30.0, 100.0)
            : 30.0,
        source: 'find_my_car', // Mark as saved via "Find My Car"
        rawNote: 'Saved via Find My Car',
        aiConfidence: aiConfidence,
      );

      // Save new session (this will automatically deactivate the old one)
      print('💾 Saving new parking session...');
      final newSessionId = await parkingService.saveParkingSession(newSession);

      print('✅ New parking session saved: $newSessionId');

      // Send local notification with recorded data and address
      try {
        await NotificationService.showParkingSavedNotification(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          altitude: position.altitude != 0.0 ? position.altitude : null,
        );
        print('✅ Notification sent successfully');
      } catch (e) {
        print('⚠️ Error sending notification: $e');
        // Don't fail the whole operation if notification fails
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New location saved! Previous location moved to history.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to the new session
        context.go('/navigate/$newSessionId');
      }
    } catch (e) {
      print('❌ Error finding my car: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving new location: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingNewLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final parkingService = context.watch<ParkingService>();

    return Scaffold(
      body: MapBackground(
        backgroundOpacity: 0.85,
        overlayOpacity: 0.25,
        child: Stack(
          children: [
          // Confetti animation overlay (top center to bottom)
          if (_showConfetti)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: 1.5708, // 90 degrees (top to bottom)
                  emissionFrequency: 0.05,
                  numberOfParticles: 70,
                  gravity: 0.3,
                  shouldLoop: false,
                  colors: const [
                    Colors.blue,
                    Colors.green,
                    Colors.yellow,
                    Colors.orange,
                    Colors.pink,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
              ),
            ),
          SafeArea(
            child: StreamBuilder(
          stream: parkingService.watchSessions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
        
            final sessions = snapshot.data ?? [];
            ParkingSession? activeSession;
            try {
              activeSession = sessions.firstWhere((s) => s.active);
            } catch (e) {
              activeSession = sessions.isNotEmpty ? sessions.first : null;
            }
        
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          ClipRRect(
                              child: Image.asset("assets/icon/app_icon.png",width: 64,height: 64,),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/save-parking'),
                            icon: const Icon(Icons.directions_car),
                            label: const Text('Save Parking Spot'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (activeSession != null) ...[
                    Builder(
                      builder: (context) {
                        final session = activeSession!;
                        final sessionId = session.id ?? '';
                        return Column(
                          children: [
                            // AI Insights Card
                            if (session.aiConfidence != null) ...[
                              Card(
                                color: session.aiConfidence!.score >= 4
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : session.aiConfidence!.score >= 3
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        session.aiConfidence!.score >= 4
                                            ? Icons.check_circle
                                            : Icons.info,
                                        color: session.aiConfidence!.score >= 4
                                            ? Colors.green
                                            : session.aiConfidence!.score >= 3
                                                ? Colors.orange
                                                : Colors.red,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              session.aiConfidence!.score >= 4
                                                  ? 'Saved with high accuracy'
                                                  : 'Accuracy: ${session.aiConfidence!.score}/5',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            if (session.aiConfidence!.score < 4)
                                              Text(
                                                session.aiConfidence!.reason,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Current Parking Spot Card
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.directions_car, color: Colors.red),
                                title: const Text('Current Parking Spot'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Saved: ${_formatDate(session.savedAt)}'),
                                    if (session.aiParsed != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          session.aiParsed!.level,
                                          session.aiParsed!.gate,
                                          session.aiParsed!.zone,
                                        ].where((s) => s != null).join(' • '),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => context.go('/navigate/$sessionId'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Find My Car Button
                            ElevatedButton.icon(
                              onPressed: _isSavingNewLocation
                                  ? null
                                  : () => _findMyCarAndSaveNewLocation(session),
                              icon: _isSavingNewLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.navigation),
                              label: Text(_isSavingNewLocation ? 'Saving New Location...' : 'Find My Car'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16,horizontal: 16),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ] else ...[
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No parking spot saved yet.\nTap "Save Parking Spot" to get started!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
        ],
      ),
    ));
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

