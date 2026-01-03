import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/parking_session_model.dart';

class ParkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  CollectionReference get _sessionsRef =>
      _firestore.collection('users').doc(_userId).collection('parkingSessions');

  Future<String> saveParkingSession(ParkingSession session) async {
    // Deactivate previous sessions
    await deactivatePreviousSessions();

    final docRef = await _sessionsRef.add(session.toFirestore());
    return docRef.id;
  }

  Future<void> updateParkingSession(String sessionId, ParkingSession session) async {
    await _sessionsRef.doc(sessionId).update(session.toFirestore());
  }

  Future<void> deactivatePreviousSessions() async {
    final activeSessions = await _sessionsRef
        .where('active', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (var doc in activeSessions.docs) {
      batch.update(doc.reference, {'active': false});
    }
    await batch.commit();
  }

  Future<String?> uploadPhoto(File photoFile, String sessionId) async {
    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(_userId)
          .child('parkingSessions')
          .child(sessionId)
          .child('photo.jpg');

      await ref.putFile(photoFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  Future<ParkingSession?> getActiveSession() async {
    final query = await _sessionsRef
        .where('active', isEqualTo: true)
        .orderBy('savedAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    return ParkingSession.fromFirestore(query.docs.first);
  }

  Future<List<ParkingSession>> getRecentSessions({int limit = 50}) async {
    final query = await _sessionsRef
        .orderBy('savedAt', descending: true)
        .limit(limit)
        .get();

    return query.docs
        .map((doc) => ParkingSession.fromFirestore(doc))
        .toList();
  }

  Future<ParkingSession?> getSessionById(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).get();
    if (!doc.exists) return null;
    return ParkingSession.fromFirestore(doc);
  }

  Stream<List<ParkingSession>> watchSessions() {
    return _sessionsRef
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ParkingSession.fromFirestore(doc))
            .toList());
  }
}

